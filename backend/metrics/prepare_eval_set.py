"""
backend/metrics/prepare_eval_set.py
===================================
Build a labelled image evaluation set from deepfake video datasets.

Usage (official FaceForensics++ tree, the default layout):
    py -3.12 backend/metrics/prepare_eval_set.py <ff++_root> <out_dir> \
        [--frames-per-video 8] [--compression c23] [--seed 20260928]

Usage (flat layout, e.g. D:\\All ZIP\\archive\\FaceForensics++_C23):
    py -3.12 backend/metrics/prepare_eval_set.py <root> <out_dir> --layout flat

Expected layouts::

    official:  <root>/original_sequences/<compression>/videos/<id>/<id>.mp4
               <root>/manipulated_sequences/<method>/<compression>/videos/<id>/<id>.mp4
    flat:      <root>/original/<id>.mp4            -> real
               <root>/<Method>/<id>.mp4           -> fake

Frames are written as PNG **full frames** (not face crops), because
``ImagePipeline`` runs its own face detection and cropping; handing it crops it
was not trained to receive biases the detection stage. Frames are downscaled to
``--max-width`` (default 640), which is still comfortably large enough for the
face detectors.

**Group-level splitting.** FaceForensics++ names a manipulated file
``<a>_<b>.mp4`` where one of the two ids is the original it was derived from and
the other is the identity being impersonated. Both ids are unioned, so a fake
and every original it relates to always land in the *same* split. Splitting by
video instead would let the real counterpart of a test fake sit in val, which
leaks the content the model would be tuned on. Groups are therefore the unit of
splitting, and selection is balanced so each split gets the same number of real
and fake videos.

Only ``cv2`` and the standard library are used; no GPU and no deep model.
"""

import argparse
import csv
import os
import random
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2

# Only the manipulated methods FaceForensics++ publishes. ``youtube`` is a real
# method but is often absent; DeepFakeDetection is deliberately absent because it
# is a separate research dataset, not an FF++ manipulation method.
MANIPULATION_METHODS = [
    "Deepfakes",
    "Face2Face",
    "FaceShifter",
    "FaceSwap",
    "NeuralTextures",
    "youtube",
]

# Folders in a flat root that are data but not FF++ manipulation methods.
NON_FFPLUS_FOLDERS = {"DeepFakeDetection", "DeepFake_Project", "csv", "original"}

REAL_LABEL = "real"
FAKE_LABEL = "fake"

DEFAULT_MAX_WIDTH = 640
DEFAULT_MAX_VIDEOS_PER_CLASS = 60


# ---------------------------------------------------------------------------
# Union-find over source/target id pairs
# ---------------------------------------------------------------------------

class UnionFind:
    """Minimal union-find, used to keep related videos in one split."""

    def __init__(self):
        self.parent: Dict[str, str] = {}

    def add(self, item: str) -> None:
        self.parent.setdefault(item, item)

    def find(self, item: str) -> str:
        self.add(item)
        root = item
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[item] != root:      # path compression
            self.parent[item], item = root, self.parent[item]
        return root

    def union(self, a: str, b: str) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            # Keep the lexicographically smaller id as the root so group ids are
            # stable across runs regardless of insertion order.
            lo, hi = sorted((ra, rb))
            self.parent[hi] = lo

    def groups(self) -> Dict[str, List[str]]:
        out: Dict[str, List[str]] = defaultdict(list)
        for item in self.parent:
            out[self.find(item)].append(item)
        return out


def parse_paired_filename(stem: str) -> Optional[Tuple[str, str]]:
    """Parse ``NNN_MMM`` into ``("NNN", "MMM")``; return None if not that shape."""
    if "_" not in stem:
        return None
    left, _, right = stem.partition("_")
    if not left or not right or "_" in right:
        return None
    if not (left.isdigit() and right.isdigit()):
        return None
    return left, right


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def find_videos_official(root: Path, compression: str) -> Tuple[List[Path], Dict[str, List[Path]]]:
    """(real videos, {method: fake videos}) for the official FaceForensics++ tree."""
    real_dir = root / "original_sequences" / compression / "videos"
    if not real_dir.is_dir():
        raise FileNotFoundError(f"Missing real videos directory: {real_dir}")
    real_videos = sorted(p for p in real_dir.glob("*/*.mp4") if p.is_file())
    if not real_videos:
        raise FileNotFoundError(f"No .mp4 files under {real_dir}")

    fakes: Dict[str, List[Path]] = {}
    manip_root = root / "manipulated_sequences"
    if manip_root.is_dir():
        for method_dir in sorted(p for p in manip_root.iterdir() if p.is_dir()):
            if method_dir.name not in MANIPULATION_METHODS:
                continue
            found = sorted(
                p for p in (method_dir / compression / "videos").glob("*/*.mp4") if p.is_file()
            )
            if found:
                fakes[method_dir.name] = found
    return real_videos, fakes


def find_videos_flat(root: Path) -> Tuple[List[Path], Dict[str, List[Path]]]:
    """(real videos, {method: fake videos}) for a flat FaceForensics++ root.

    ``original/`` is the real class. A method folder contributes only if it is a
    known FF++ manipulation method *and* actually contains videos, so partially
    downloaded method folders are ignored rather than silently biasing the set.
    """
    real_dir = root / "original"
    if not real_dir.is_dir():
        raise FileNotFoundError(f"Missing real videos directory: {real_dir}")
    real_videos = sorted(p for p in real_dir.glob("*.mp4") if p.is_file())
    if not real_videos:
        raise FileNotFoundError(f"No .mp4 files under {real_dir}")

    fakes: Dict[str, List[Path]] = {}
    for method_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        if method_dir.name in NON_FFPLUS_FOLDERS or method_dir.name == "original":
            continue
        if method_dir.name not in MANIPULATION_METHODS:
            continue
        found = sorted(p for p in method_dir.glob("*.mp4") if p.is_file())
        if found:
            fakes[method_dir.name] = found
    return real_videos, fakes


# ---------------------------------------------------------------------------
# Frame extraction
# ---------------------------------------------------------------------------

def sample_frame_indices(total_frames: int, count: int) -> List[int]:
    """Evenly spaced frame indices across the video, including the first and last frame.

    Endpoints are included deliberately: stepping by ``total / count`` instead
    would leave the final ~1/count of every video unsampled.
    """
    if total_frames <= 0 or count < 1:
        return []
    if total_frames <= count:
        return list(range(total_frames))
    if count == 1:
        return [0]
    last = total_frames - 1
    return sorted({int(round(i * last / float(count - 1))) for i in range(count)})


def extract_frames(video_path: Path, out_dir: Path, count: int, max_width: int) -> List[str]:
    """Write up to ``count`` full frames from ``video_path``. Returns written filenames."""
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        return []

    try:
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total <= 0:
            return []
        out_dir.mkdir(parents=True, exist_ok=True)
        written: List[str] = []

        for idx in sample_frame_indices(total, count):
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ok, frame = cap.read()
            if not ok or frame is None:
                continue
            if max_width and frame.shape[1] > max_width:
                scale = max_width / float(frame.shape[1])
                frame = cv2.resize(
                    frame,
                    (max_width, max(1, int(frame.shape[0] * scale))),
                    interpolation=cv2.INTER_AREA,
                )
            name = f"{video_path.stem}_{idx:05d}.png"
            if cv2.imwrite(str(out_dir / name), frame):
                written.append(name)
        return written
    finally:
        cap.release()


# ---------------------------------------------------------------------------
# Grouping, selection and splitting
# ---------------------------------------------------------------------------

def build_groups(
    real_videos: List[Path],
    fakes: Dict[str, List[Path]],
) -> Dict[str, Dict[str, list]]:
    """Group videos by connected source/target relation.

    Returns ``{group_id: {"real": [Path], "fake": [(Path, method)]}}``. A video
    with no related counterpart forms a group of its own.
    """
    uf = UnionFind()
    for p in real_videos:
        uf.add(p.stem)
    for paths in fakes.values():
        for p in paths:
            pair = parse_paired_filename(p.stem)
            if pair:
                # Both ids join the same component, whichever end is the source,
                # and the fake's own "<a>_<b>" stem joins that component too -
                # otherwise the manipulated file would sit in a group of its own
                # and could be split away from the original it came from.
                uf.union(pair[0], pair[1])
                uf.union(p.stem, pair[0])

    groups: Dict[str, Dict[str, list]] = defaultdict(lambda: {"real": [], "fake": []})
    for p in real_videos:
        groups[uf.find(p.stem)]["real"].append(p)
    for method, paths in fakes.items():
        for p in paths:
            groups[uf.find(p.stem)]["fake"].append((p, method))
    return dict(groups)


def assign_splits(groups: Dict[str, Dict[str, list]], seed: int) -> Dict[str, str]:
    """Split at GROUP level, 50/50, so a group never spans both splits."""
    rng = random.Random(seed)
    ids = sorted(groups)
    rng.shuffle(ids)
    half = len(ids) // 2
    return {gid: ("val" if i < half else "test") for i, gid in enumerate(ids)}


def select_balanced(
    groups: Dict[str, Dict[str, list]],
    splits: Dict[str, str],
    cap_per_class: int,
    seed: int,
) -> List[Tuple[Path, str, str, str]]:
    """Pick whole groups so each split gets equal real and fake counts, capped.

    Returns ``[(path, label, method, group_id)]``. Groups are consumed whole, so
    a real and the fake derived from it are always both kept or both dropped.
    """
    rng = random.Random(seed)
    by_split: Dict[str, List[str]] = defaultdict(list)
    for gid, split in splits.items():
        by_split[split].append(gid)

    selected: List[Tuple[Path, str, str, str]] = []
    for split in sorted(by_split):
        ids = sorted(by_split[split])
        rng.shuffle(ids)
        n_real = n_fake = 0
        for gid in ids:
            if n_real >= cap_per_class and n_fake >= cap_per_class:
                break
            block = groups[gid]
            reals = sorted(block["real"])
            fakes = sorted(block["fake"], key=lambda t: t[0].name)
            if not fakes:
                # An original that no manipulated file derives from cannot be
                # paired, so keeping it would add unpaired real content and break
                # the per-split balance for no comparable gain.
                continue
            # Take at most one video per class per group, and always both when
            # both exist, so a group is never kept with only its fake or only
            # its real - that is what keeps a pair on the same side of the split.
            if reals and n_real < cap_per_class:
                selected.append((reals[0], REAL_LABEL, "original", gid))
                n_real += 1
            if fakes and n_fake < cap_per_class:
                selected.append((fakes[0][0], FAKE_LABEL, fakes[0][1], gid))
                n_fake += 1
    return selected


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build(
    root: Path,
    out_dir: Path,
    frames_per_video: int,
    compression: str,
    seed: int,
    max_videos_per_class: int,
    max_width: int,
    layout: str = "official",
) -> Path:
    if layout == "flat":
        real_videos, fakes = find_videos_flat(root)
    else:
        real_videos, fakes = find_videos_official(root, compression)

    print(f"[INFO] Layout        : {layout}")
    print(f"[INFO] Real videos   : {len(real_videos)}")
    for method in sorted(fakes):
        print(f"[INFO] Fake videos   : {method}: {len(fakes[method])}")
    if not fakes:
        print("[WARN] No fake videos found - the evaluation set will have no fake class.")
    elif len(fakes) == 1:
        print(f"[WARN] Only one manipulation method ({next(iter(fakes))}) has videos on disk. "
              "Results apply to that method only, not to deepfakes in general.")

    groups = build_groups(real_videos, fakes)
    splits = assign_splits(groups, seed)
    selected = select_balanced(groups, splits, max_videos_per_class, seed)
    if not selected:
        raise SystemExit("[ERROR] No videos selected.")

    rows: List[Dict[str, object]] = []
    for video_path, label, method, group_id in selected:
        split = splits[group_id]
        target = out_dir / split / label
        for name in extract_frames(video_path, target, frames_per_video, max_width):
            rows.append(
                {
                    "path": (target / name).as_posix(),
                    "label": 0 if label == REAL_LABEL else 1,
                    "split": split,
                    "video_id": video_path.stem,
                    "method": method,
                    "group_id": group_id,
                }
            )

    manifest = out_dir / "manifest.csv"
    out_dir.mkdir(parents=True, exist_ok=True)
    with open(manifest, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh, fieldnames=["path", "label", "split", "video_id", "method", "group_id"]
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"[INFO] groups         : {len(groups)} (split unit)")
    print(f"[INFO] videos selected: {len(selected)}")
    print(f"[INFO] frames written : {len(rows)}")
    print(f"[INFO] manifest       : {manifest}")
    for split in ("val", "test"):
        for label, name in ((0, REAL_LABEL), (1, FAKE_LABEL)):
            sub = [r for r in rows if r["split"] == split and r["label"] == label]
            print(f"[INFO] {split:<5} {name:<5} videos={len({r['video_id'] for r in sub}):<4} frames={len(sub)}")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("root", help="Dataset root (see layouts in the module docstring)")
    parser.add_argument("out_dir", help="Output directory for the evaluation set")
    parser.add_argument("--layout", choices=["official", "flat"], default="official")
    parser.add_argument("--frames-per-video", type=int, default=8)
    parser.add_argument("--compression", default="c23", help="FF++ compression variant (official layout only)")
    parser.add_argument("--seed", type=int, default=20260928)
    parser.add_argument("--max-videos-per-class", type=int, default=DEFAULT_MAX_VIDEOS_PER_CLASS)
    parser.add_argument("--max-width", type=int, default=DEFAULT_MAX_WIDTH)
    args = parser.parse_args()

    if args.frames_per_video < 1:
        print("[ERROR] --frames-per-video must be >= 1", file=sys.stderr)
        sys.exit(1)
    if args.max_videos_per_class < 1:
        print("[ERROR] --max-videos-per-class must be >= 1", file=sys.stderr)
        sys.exit(1)

    build(
        Path(args.root).resolve(),
        Path(args.out_dir).resolve(),
        args.frames_per_video,
        args.compression,
        args.seed,
        args.max_videos_per_class,
        args.max_width,
        args.layout,
    )


if __name__ == "__main__":
    main()
