import csv
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import cv2
import numpy as np

from metrics.prepare_eval_set import (
    UnionFind,
    assign_splits,
    build,
    build_groups,
    find_videos_flat,
    parse_paired_filename,
    sample_frame_indices,
    select_balanced,
)


def _write_video(path: Path, num_frames: int = 24, size=(160, 120)) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), 25, size)
    if not writer.isOpened():
        raise unittest.SkipTest("cv2.VideoWriter cannot write mp4v on this build")
    try:
        for i in range(num_frames):
            writer.write(np.full((size[1], size[0], 3), (i * 7) % 255, dtype=np.uint8))
    finally:
        writer.release()


def _make_flat_root(base: Path) -> Path:
    """Flat FF++ root: original/ = real, Deepfakes/ = fake named <src>_<tgt>.mp4.

    Fakes chain together on purpose (000_010, 010_020) so one connected
    component spans three ids, which is what makes group-level splitting matter.
    """
    root = base / "ffpp_flat"
    for i in range(6):
        _write_video(root / "original" / f"{i:03d}.mp4")
    for name in ["000_010", "010_020", "001_011", "002_012", "003_013", "004_014"]:
        _write_video(root / "Deepfakes" / f"{name}.mp4")
    return root


class TestParsePairedFilename(unittest.TestCase):
    def test_parses_two_numeric_ids(self):
        self.assertEqual(parse_paired_filename("000_010"), ("000", "010"))

    def test_rejects_unpaired_and_non_numeric(self):
        for stem in ["000", "abc_def", "000_010_020", "_010", "000_", "Deepfakes_010"]:
            self.assertIsNone(parse_paired_filename(stem), stem)


class TestUnionFind(unittest.TestCase):
    def test_chains_merge_into_one_component(self):
        uf = UnionFind()
        uf.union("000", "010")
        uf.union("010", "020")
        self.assertEqual(uf.find("000"), uf.find("020"))

    def test_disjoint_ids_stay_apart(self):
        uf = UnionFind()
        uf.union("000", "010")
        uf.union("001", "011")
        self.assertNotEqual(uf.find("000"), uf.find("001"))

    def test_root_is_stable_lexicographic(self):
        uf = UnionFind()
        uf.union("020", "010")
        self.assertEqual(uf.find("020"), "010")


class TestFlatDiscovery(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = _make_flat_root(self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_original_is_real_and_deepfakes_is_fake(self):
        real, fakes = find_videos_flat(self.root)
        self.assertEqual(len(real), 6)
        self.assertEqual(sorted(fakes), ["Deepfakes"])
        self.assertEqual(len(fakes["Deepfakes"]), 6)

    def test_ignores_deepfakedetection_and_non_method_folders(self):
        _write_video(self.root / "DeepFakeDetection" / "01_abc.mp4")
        _write_video(self.root / "csv" / "junk.mp4")
        _write_video(self.root / "Face2Face" / "000_001.mp4")   # method, but no videos? kept
        real, fakes = find_videos_flat(self.root)
        self.assertNotIn("DeepFakeDetection", fakes)
        self.assertNotIn("csv", fakes)
        self.assertIn("Face2Face", fakes)

    def test_missing_root_raises(self):
        with self.assertRaises(FileNotFoundError):
            find_videos_flat(self.tmp / "nope")


class TestGroupingAndSplitting(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = _make_flat_root(self.tmp)
        self.real, self.fakes = find_videos_flat(self.root)
        self.groups = build_groups(self.real, self.fakes)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_chained_fakes_land_in_one_group(self):
        # 000_010 and 010_020 chain, so ids 000, 010 and 020 share a group.
        sizes = sorted((len(g["real"]) + len(g["fake"])) for g in self.groups.values())
        self.assertEqual(sizes[-1], 3)

    def test_every_video_belongs_to_exactly_one_group(self):
        seen = 0
        for block in self.groups.values():
            seen += len(block["real"]) + len(block["fake"])
        self.assertEqual(seen, len(self.real) + len(self.fakes["Deepfakes"]))

    def test_each_group_gets_exactly_one_split(self):
        splits = assign_splits(self.groups, seed=11)
        self.assertEqual(len(splits), len(self.groups), "every group needs a split")
        self.assertEqual(set(splits.values()), {"val", "test"})

    def test_related_videos_share_one_group(self):
        group_of = {}
        for gid, block in self.groups.items():
            for p in block["real"]:
                group_of[p.stem] = gid
            for p, _ in block["fake"]:
                group_of[p.stem] = gid
        # 000_010 and 010_020 chain through id 010, so all three ids sit together.
        for fake_stem, counterpart in (("000_010", "000"), ("010_020", "000")):
            self.assertEqual(group_of[fake_stem], group_of[counterpart], fake_stem)

    def test_selection_keeps_whole_groups_and_balances_classes(self):
        splits = assign_splits(self.groups, seed=11)
        selected = select_balanced(self.groups, splits, cap_per_class=60, seed=11)
        self.assertTrue(selected)
        for gid in {s[3] for s in selected}:
            kept = [s for s in selected if s[3] == gid]
            self.assertEqual(
                {s[1] for s in kept}, {"real", "fake"},
                f"group {gid} contributed only one class",
            )
        for split in ("val", "test"):
            per_split = [s for s in selected if splits[s[3]] == split]
            n_real = sum(1 for s in per_split if s[1] == "real")
            n_fake = sum(1 for s in per_split if s[1] == "fake")
            self.assertEqual(n_real, n_fake, f"{split} is unbalanced")

    def test_unpaired_real_groups_are_skipped(self):
        # original/005 has no fake derived from it, so it cannot be paired.
        splits = assign_splits(self.groups, seed=11)
        selected = select_balanced(self.groups, splits, cap_per_class=60, seed=11)
        self.assertNotIn("005", {s[0].stem for s in selected})

    def test_cap_is_respected(self):
        splits = assign_splits(self.groups, seed=11)
        selected = select_balanced(self.groups, splits, cap_per_class=1, seed=11)
        self.assertLessEqual(len(selected), 4)   # 2 splits x (1 real + 1 fake)


class TestSampleFrameIndices(unittest.TestCase):
    def test_endpoints_included(self):
        self.assertEqual(sample_frame_indices(100, 5), [0, 25, 50, 74, 99])

    def test_single_frame(self):
        self.assertEqual(sample_frame_indices(100, 1), [0])

    def test_short_video_all_frames(self):
        self.assertEqual(sample_frame_indices(3, 8), [0, 1, 2])

    def test_empty(self):
        self.assertEqual(sample_frame_indices(0, 8), [])


class TestBuildFlat(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = _make_flat_root(self.tmp)
        self.out = self.tmp / "eval_dataset"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _build(self):
        return build(
            self.root, self.out, frames_per_video=3, compression="c23",
            seed=7, max_videos_per_class=4, max_width=160, layout="flat",
        )

    def test_manifest_has_group_id_column(self):
        manifest = self._build()
        with open(manifest, newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        self.assertTrue(rows)
        self.assertEqual(
            list(rows[0].keys()),
            ["path", "label", "split", "video_id", "method", "group_id"],
        )

    def test_frames_are_full_frames_and_exist(self):
        self._build()
        with open(self.out / "manifest.csv", newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        for row in rows:
            p = Path(row["path"])
            self.assertTrue(p.is_file(), f"missing {p}")
            self.assertEqual(p.suffix, ".png")
            frame = cv2.imread(str(p))
            self.assertEqual(frame.shape[:2], (120, 160))

    def test_no_group_spans_both_splits_in_written_manifest(self):
        self._build()
        with open(self.out / "manifest.csv", newline="", encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        per_group = {}
        for row in rows:
            per_group.setdefault(row["group_id"], set()).add(row["split"])
        for gid, splits in per_group.items():
            self.assertEqual(len(splits), 1, f"group {gid} leaked across {splits}")

    def test_label_matches_folder(self):
        self._build()
        with open(self.out / "manifest.csv", newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                label = "fake" if row["label"] == "1" else "real"
                self.assertIn(f"/{label}/", row["path"])


if __name__ == "__main__":
    unittest.main()
