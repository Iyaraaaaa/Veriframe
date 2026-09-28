"""
backend/metrics/run_eval.py
===========================
Evaluation harness for the image deepfake detection pipeline.

Usage:
    py -3.12 backend/metrics/run_eval.py <folder> [--threshold 0.5] [--resume]

<folder> must contain:
    real/   – images labelled AUTHENTIC  (label = 0)
    fake/   – images labelled FAKE       (label = 1)

Optionally a ``manifest.csv`` (as written by ``prepare_eval_set.py``) sitting in
<folder> or its parent supplies ``video_id`` and ``method`` for each frame, which
enables video-level metrics and per-method recall.

Outputs:
    <folder>/results.csv  – per-file scores, path used, video_id, method.
        Written incrementally: the header goes out first and one row is
        appended and flushed per image, so a crash or Ctrl-C never costs more
        than the image in flight. ``--resume`` picks the run up from there.
    Prints frame-level, video-level, per-path and per-method metrics to stdout,
    always computed by re-reading results.csv, so a resumed run reports
    exactly what an uninterrupted one would.

Every number printed here is computed from files actually present on disk. No
metric is invented, and any group with fewer than ``MIN_GROUP_ROWS`` rows is
reported as skipped rather than summarised from too few samples.
"""

import argparse
import csv
import os
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Bootstrap: make sure backend/ is on sys.path regardless of CWD
# ---------------------------------------------------------------------------
_here = Path(__file__).resolve().parent          # backend/metrics/
_backend = _here.parent                          # backend/
if str(_backend) not in sys.path:
    sys.path.insert(0, str(_backend))

from metrics.evaluator import MetricsEvaluator   # noqa: E402

# A group smaller than this is not summarised: its accuracy/F1 would swing by
# tens of points on a handful of samples and would misrepresent the model.
MIN_GROUP_ROWS = 10

# How often the in-flight run reports progress on stdout.
PROGRESS_EVERY = 25

# Column order of results.csv. Fixed so a resumed run appends rows in exactly
# the shape the first run wrote.
FIELDNAMES = ["file", "label", "score", "local_score", "rd_score", "rd_status",
              "verdict", "path_used", "video_id", "method"]

FACE = "face"
FALLBACK = "fallback"


# ---------------------------------------------------------------------------
# ECE – Expected Calibration Error (10 equal-width bins)
# ---------------------------------------------------------------------------

def compute_ece(y_true: np.ndarray, y_prob: np.ndarray, n_bins: int = 10) -> float:
    """Compute Expected Calibration Error using equal-width confidence bins."""
    bins = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    n = len(y_true)
    for lo, hi in zip(bins[:-1], bins[1:]):
        mask = (y_prob >= lo) & (y_prob < hi)
        if not mask.any():
            continue
        bin_acc = float(np.mean(y_true[mask] == (y_prob[mask] >= 0.5).astype(int)))
        bin_conf = float(np.mean(y_prob[mask]))
        ece += mask.sum() / n * abs(bin_acc - bin_conf)
    return round(ece, 4)


# ---------------------------------------------------------------------------
# Image pipeline loader (minimal – no server needed)
# ---------------------------------------------------------------------------

def _load_pipeline(engines: str = "local"):
    """Load ImagePipeline with real tflite models.

    ``engines``:
        local  – RD mocked out, no network calls (default; safe for bulk eval)
        rd     – real Reality Defender service
        fused  – real Reality Defender service, pipeline's own 50/50 fusion

    Gemini is never invoked: it is an explanation step in main.py and has no
    bearing on a score.
    """
    # Lazy import so the script can still give usage advice even if deps missing
    try:
        import tflite_runtime.interpreter as tflite
    except ImportError:
        try:
            import tensorflow as tf
            tflite = tf.lite
        except ImportError:
            print("[ERROR] Neither tflite_runtime nor tensorflow found. "
                  "Install one of them first.", file=sys.stderr)
            sys.exit(1)

    # Resolve model path: prefer Image.tflite, fall back to veriframe_model.tflite
    model_search = [
        _backend / "Image.tflite",
        _backend / "veriframe_model.tflite",
    ]
    model_path = next((p for p in model_search if p.exists()), None)
    if model_path is None:
        print("[ERROR] No .tflite model found. "
              "Expected one of:", file=sys.stderr)
        for p in model_search:
            print(f"  {p}", file=sys.stderr)
        sys.exit(1)

    interpreter = tflite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    from detectors.face_detector import FaceDetector  # noqa: E402
    from calibration.confidence_calibration import ConfidenceCalibrator  # noqa: E402
    from preprocessing.preprocessor import FramePreprocessor  # noqa: E402
    from pipelines.image_pipeline import ImagePipeline  # noqa: E402
    from filters.scene_forensics import SceneForensicsAnalyzer  # noqa: E402
    from config import config as app_config  # noqa: E402
    from services.reality_defender_service import RealityDefenderService  # noqa: E402
    from unittest.mock import MagicMock  # noqa: E402

    face_detector = FaceDetector(input_size=app_config.INPUT_SIZE)
    calibrator = ConfidenceCalibrator(temperature=app_config.CONFIDENCE_CALIBRATION_TEMP)
    preprocessor = FramePreprocessor(target_size=app_config.INPUT_SIZE)
    scene_analyzer = SceneForensicsAnalyzer()

    # Reality Defender is opt-in: each call costs quota, so bulk evaluation must
    # never reach the network unless the operator asked for it.
    from unittest.mock import MagicMock  # noqa: E402

    if engines == "local":
        mock_rd = MagicMock(spec=RealityDefenderService)
        mock_rd.detector = MagicMock()
        mock_rd.detector.is_configured.return_value = False
        rd_service = mock_rd
    else:
        rd_service = RealityDefenderService()
        if not rd_service.detector.is_configured():
            print(f"[ERROR] --engines {engines} requested but Reality Defender is not "
                  "configured (no access token). Re-run with --local-only.", file=sys.stderr)
            sys.exit(1)
        print("[WARN] Reality Defender ENABLED - every image is a billed API call. "
              "Use --max-frames-per-video to cap the cost.")

    pipeline = ImagePipeline(
        interpreter=interpreter,
        input_details=input_details,
        output_details=output_details,
        face_detector=face_detector,
        calibrator=calibrator,
        preprocessor=preprocessor,
        scene_analyzer=scene_analyzer,
        rd_service=rd_service,
        model_used=model_path.stem,
    )
    return pipeline


# ---------------------------------------------------------------------------
# File discovery helpers
# ---------------------------------------------------------------------------

_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff", ".tif"}


def _collect_files(folder: Path, label: int):
    """Yield (Path, label) for all image files in folder (non-recursive)."""
    if not folder.is_dir():
        return
    for p in sorted(folder.iterdir()):
        if p.suffix.lower() in _IMAGE_EXTS:
            yield p, label


def classify_path_used(result: Dict) -> str:
    """Whether the classifier scored a detected face or the whole frame.

    Read from the pipeline's own forensic observations rather than inferred from
    the score, because a real photo and the full-scene fallback can produce the
    same score range.
    """
    for obs in result.get("forensicObservations") or []:
        if obs.startswith("Face Model"):
            return FACE
    for obs in result.get("forensicObservations") or []:
        if obs.startswith("Full-Scene Inference"):
            return FALLBACK
    return "unknown"


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def load_manifest(root: Path) -> Dict[str, Dict[str, str]]:
    """Load manifest.csv keyed by normalised path, then by bare filename.

    Looks in ``root`` and its parent, because ``prepare_eval_set.py`` writes the
    manifest next to the ``val``/``test`` folders rather than inside each.
    """
    for candidate in (root / "manifest.csv", root.parent / "manifest.csv"):
        if not candidate.is_file():
            continue
        by_path: Dict[str, Dict[str, str]] = {}
        with open(candidate, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                raw = (row.get("path") or "").strip()
                if not raw:
                    continue
                by_path[os.path.normcase(os.path.abspath(raw))] = row
                by_path[Path(raw).name] = row
        return by_path
    return {}


def lookup_manifest(manifest: Dict[str, Dict[str, str]], path: Path) -> Dict[str, str]:
    if not manifest:
        return {}
    return (
        manifest.get(os.path.normcase(os.path.abspath(str(path))))
        or manifest.get(path.name)
        or {}
    )


# ---------------------------------------------------------------------------
# Metric helpers
# ---------------------------------------------------------------------------

def _metric_block(y_true: List[int], y_prob: List[float], threshold: float) -> Dict:
    yt = np.array(y_true, dtype=int)
    yp = np.array(y_prob, dtype=float)
    m = MetricsEvaluator.compute_metrics(yt, yp, threshold=threshold)
    return {
        "n": len(y_true),
        "accuracy": m["accuracy"],
        "precision": m["precision"],
        "recall": m["recall"],
        "f1": m["f1_score"],
        "auc": m["auc"],
        "ece": compute_ece(yt, yp),
        "cm": m["confusion_matrix"],
    }


def _print_metric_block(title: str, block: Dict) -> None:
    cm = block["cm"]
    print(f"  {title}")
    print(f"    n={block['n']}  accuracy={block['accuracy']:.4f}  f1={block['f1']:.4f}  "
          f"auc={block['auc']:.4f}  ece={block['ece']:.4f}")
    print(f"    precision={block['precision']:.4f}  recall={block['recall']:.4f}  "
          f"TP={cm['tp']} TN={cm['tn']} FP={cm['fp']} FN={cm['fn']}")


def _too_small(n: int) -> bool:
    return n < MIN_GROUP_ROWS


# ---------------------------------------------------------------------------
# Incremental result store
# ---------------------------------------------------------------------------

def read_results(csv_path: Path) -> List[Dict]:
    """Read results.csv back into typed rows.

    Every metric is computed from this, never from in-memory state, so a
    resumed run and an uninterrupted one cannot disagree.
    """
    if not csv_path.is_file():
        return []
    rows: List[Dict] = []
    with open(csv_path, newline="", encoding="utf-8") as fh:
        for raw in csv.DictReader(fh):
            if not (raw.get("file") or "").strip():
                continue
            rows.append({
                "file": raw.get("file", "").strip(),
                "label": int(float(raw.get("label") or 0)),
                "score": float(raw.get("score") or 0.0),
                "local_score": raw.get("local_score") or "",
                "rd_score": raw.get("rd_score") or "",
                "rd_status": raw.get("rd_status") or "",
                "verdict": raw.get("verdict") or "UNKNOWN",
                "path_used": raw.get("path_used") or "unknown",
                "video_id": raw.get("video_id") or "",
                "method": raw.get("method") or "",
            })
    return rows


def _row_key(row: Dict) -> Tuple[str, str]:
    """Identity of a scored image: name plus label, since real/ and fake/ can
    legitimately hold the same filename."""
    label = row.get("label")
    return (row.get("file") or "", "" if label is None else str(label))


def _hms(seconds: float) -> str:
    seconds = int(max(0.0, seconds))
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def evaluate_image(pipeline, img_path: Path) -> Dict:
    """Score one image, degrading to an ERROR row rather than losing the run."""
    try:
        result = pipeline.process(str(img_path))
        return {
            # fakeProbability is 0-100; normalise to [0, 1]
            "score": result.get("fakeProbability", 50.0) / 100.0,
            "verdict": result.get("verdict", "UNKNOWN"),
            "path_used": classify_path_used(result),
            "local_score": result.get("local_fake_probability"),
            "rd_score": result.get("rd_fake_probability"),
            "rd_status": result.get("rd_status", "not_run"),
        }
    except Exception as exc:
        print(f"[WARN] {img_path.name}: pipeline error – {exc}", file=sys.stderr)
        return {
            "score": 0.5,
            "verdict": "ERROR",
            "path_used": "error",
            "local_score": None,
            "rd_score": None,
            "rd_status": "error",
        }


def run_evaluation(files, manifest: Dict, pipeline, csv_path: Path,
                   max_frames_per_video: int = 8, resume: bool = False,
                   progress_every: int = PROGRESS_EVERY) -> List[Dict]:
    """Score ``files`` into ``csv_path``, one flushed row per image.

    The file is opened before the first image is scored, so the header and every
    scored row survive a crash. With ``resume``, rows already present are kept
    and their images are skipped; the per-video frame cap is re-seeded from
    those rows so a resumed run selects the same frames as a single run.

    Returns the rows read back from the CSV.
    """
    already: List[Dict] = read_results(csv_path) if resume else []
    done_keys = {_row_key(r) for r in already}

    # Re-seed the cap from the rows an earlier run already wrote, otherwise a
    # resume would happily blow past --max-frames-per-video for the videos it
    # had partly done.
    seen_videos: Dict[str, int] = defaultdict(int)
    for row in already:
        if row["video_id"]:
            seen_videos[row["video_id"]] += 1

    todo = [(path, label) for path, label in files
            if (path.name, str(label)) not in done_keys]
    skipped_done = len(files) - len(todo)

    if already:
        print(f"[INFO] Resuming: {len(already)} row(s) already in {csv_path.name}, "
              f"{len(todo)} image(s) left to score.")
    if not todo:
        if not already:
            print("[WARN] Nothing to score.")
        return read_results(csv_path)

    # Append only when resuming onto rows an earlier run actually wrote.
    # A fresh run truncates, and a truncated file always needs the header again.
    appending = resume and csv_path.is_file() and csv_path.stat().st_size > 0
    handle = open(csv_path, "a" if appending else "w", newline="", encoding="utf-8")
    try:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        if not appending:
            writer.writeheader()
            handle.flush()

        total = len(todo)
        started = time.time()
        skipped_by_cap = 0

        for done, (img_path, label) in enumerate(todo, start=1):
            meta = lookup_manifest(manifest, img_path)
            video_id = meta.get("video_id", "")

            # Cap frames per video so a RD run stays within quota.
            if video_id and seen_videos[video_id] >= max_frames_per_video:
                skipped_by_cap += 1
                continue
            if video_id:
                seen_videos[video_id] += 1

            scored = evaluate_image(pipeline, img_path)
            writer.writerow({
                "file": img_path.name,
                "label": label,
                "score": scored["score"],
                "local_score": ("" if scored["local_score"] is None
                                else round(float(scored["local_score"]), 6)),
                "rd_score": ("" if scored["rd_score"] is None
                             else round(float(scored["rd_score"]), 6)),
                "rd_status": scored["rd_status"],
                "verdict": scored["verdict"],
                "path_used": scored["path_used"],
                "video_id": video_id,
                "method": meta.get("method", ""),
            })
            handle.flush()

            if done % progress_every == 0 or done == total:
                elapsed = time.time() - started
                rate = done / elapsed if elapsed > 0 else 0.0
                eta = (total - done) / rate if rate > 0 else 0.0
                print(f"[PROGRESS] {done}/{total} scored | elapsed {_hms(elapsed)} | "
                      f"ETA {_hms(eta)}")

        if skipped_by_cap:
            print(f"[INFO] Skipped {skipped_by_cap} frame(s) above the "
                  f"--max-frames-per-video cap of {max_frames_per_video}.")
    finally:
        handle.close()

    if skipped_done:
        print(f"[INFO] {skipped_done} image(s) were already scored in an earlier run.")
    return read_results(csv_path)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Run image pipeline evaluation on a real/fake folder pair."
    )
    parser.add_argument(
        "folder",
        nargs="?",
        default=None,
        help="Path to folder containing real/ and fake/ subdirectories.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="Fake probability at or above which a sample counts as FAKE (default 0.5).",
    )
    parser.add_argument(
        "--engines",
        choices=["local", "rd", "fused"],
        default="local",
        help="local: no network (default). rd: Reality Defender only. fused: local + RD.",
    )
    parser.add_argument(
        "--local-only",
        action="store_true",
        help="Alias for --engines local. Disables Reality Defender and any explanation model.",
    )
    parser.add_argument(
        "--max-frames-per-video",
        type=int,
        default=8,
        help="Evaluate at most this many frames per video. Caps RD cost. Needs a manifest.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Continue an interrupted run: keep the rows already in results.csv "
             "and score only the images missing from it.",
    )
    args = parser.parse_args()

    if args.folder is None:
        print(__doc__)
        sys.exit(0)

    if args.local_only:
        args.engines = "local"

    if not 0.0 < args.threshold < 1.0:
        print("[ERROR] --threshold must be between 0 and 1", file=sys.stderr)
        sys.exit(1)

    threshold = args.threshold
    root = Path(args.folder).resolve()
    real_dir = root / "real"
    fake_dir = root / "fake"

    missing = [d for d in (real_dir, fake_dir) if not d.is_dir()]
    if missing:
        print("[ERROR] Missing subdirectories:")
        for d in missing:
            print(f"  {d}")
        print()
        print("Create real/ and fake/ subdirectories inside the folder and")
        print("place image files inside them before running this script.")
        sys.exit(1)

    files = list(_collect_files(real_dir, label=0)) + \
            list(_collect_files(fake_dir, label=1))

    if not files:
        print("[ERROR] No image files found in real/ or fake/.")
        print(f"Supported extensions: {', '.join(sorted(_IMAGE_EXTS))}")
        sys.exit(1)

    manifest = load_manifest(root)
    if manifest:
        print(f"[INFO] Manifest loaded - video_id/method available for {len(manifest)} entries.")
    else:
        print("[INFO] No manifest.csv found - video-level and per-method metrics will be skipped.")

    print(f"[INFO] Found {len(files)} image(s) — loading pipeline …")
    print(f"[INFO] Engines: {args.engines}")
    pipeline = _load_pipeline(args.engines)

    results = run_evaluation(
        files=files,
        manifest=manifest,
        pipeline=pipeline,
        csv_path=root / "results.csv",
        max_frames_per_video=args.max_frames_per_video,
        resume=args.resume,
    )
    print(f"[INFO] Results in {root / 'results.csv'} ({len(results)} row(s))")
    print(f"[INFO] Threshold applied: {threshold:.4f}")

    report_metrics(results, threshold)


def report_metrics(results: List[Dict], threshold: float) -> None:
    """Print every metric block for a set of result rows.

    Kept separate from the evaluation loop so the reporting can be exercised
    directly on rows read back from results.csv.
    """
    # -----------------------------------------------------------------------
    # Frame-level metrics (correlated: frames of one video are not independent)
    # -----------------------------------------------------------------------
    frame_block = _metric_block([r["label"] for r in results],
                                [r["score"] for r in results], threshold)
    print()
    print("=" * 56)
    print("  FRAME-LEVEL METRICS")
    print("=" * 56)
    print(f"  Rows in results.csv : {len(results)}")
    _print_metric_block("all frames", frame_block)
    print("  NOTE: frames from one video are correlated, so these numbers are")
    print("        optimistic. Use the video-level block below for reporting.")


    # -----------------------------------------------------------------------
    # Path used: face vs fallback
    # -----------------------------------------------------------------------
    print()
    print("=" * 56)
    print("  BY PIPELINE PATH")
    print("=" * 56)
    by_path: Dict[str, List[int]] = defaultdict(list)
    by_path_scores: Dict[str, List[float]] = defaultdict(list)
    for r in results:
        by_path[r["path_used"]].append(r["label"])
        by_path_scores[r["path_used"]].append(r["score"])

    for name in (FACE, FALLBACK, "unknown", "error"):
        if name not in by_path:
            continue
        n = len(by_path[name])
        if _too_small(n):
            print(f"  {name}: skipped, n={n} (< {MIN_GROUP_ROWS} rows)")
            continue
        _print_metric_block(name, _metric_block(by_path[name], by_path_scores[name], threshold))

    # -----------------------------------------------------------------------
    # Video-level metrics (one averaged score per video - the honest unit)
    # -----------------------------------------------------------------------
    print()
    print("=" * 56)
    print("  VIDEO-LEVEL METRICS")
    print("=" * 56)
    per_video: Dict[str, List[Dict]] = defaultdict(list)
    for r in results:
        if r["video_id"]:
            per_video[r["video_id"]].append(r)

    if not per_video:
        print("  Skipped: no video_id available (run prepare_eval_set.py to create a manifest).")
    else:
        v_labels: List[int] = []
        v_scores: List[float] = []
        v_methods: Dict[str, List[int]] = defaultdict(list)
        v_methods_scores: Dict[str, List[float]] = defaultdict(list)
        for vid, rows in sorted(per_video.items()):
            labels = {r["label"] for r in rows}
            if len(labels) > 1:
                print(f"  [WARN] video {vid} has mixed labels {labels}; using the first.")
            mean_score = float(np.mean([r["score"] for r in rows]))
            label = rows[0]["label"]
            v_labels.append(label)
            v_scores.append(mean_score)
            method = rows[0]["method"] or "unknown"
            v_methods[method].append(label)
            v_methods_scores[method].append(mean_score)

        if _too_small(len(v_labels)):
            print(f"  Skipped: n={len(v_labels)} videos (< {MIN_GROUP_ROWS}).")
        else:
            _print_metric_block("per video (mean of frames)",
                                _metric_block(v_labels, v_scores, threshold))
            print()
            print("  Recall per method (fake videos only):")
            for method in sorted(v_methods):
                labels = v_methods[method]
                n = len(labels)
                n_fake = sum(labels)
                if n_fake == 0 or _too_small(n_fake):
                    print(f"    {method:<20} skipped, n_fake={n_fake} (< {MIN_GROUP_ROWS})")
                    continue
                scores = v_methods_scores[method]
                detected = sum(1 for lb, s in zip(labels, scores) if lb == 1 and s >= threshold)
                print(f"    {method:<20} recall={detected / n_fake:.4f}  n_fake={n_fake}  n_videos={n}")

    print("=" * 56)


if __name__ == "__main__":
    main()
