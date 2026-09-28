import csv
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from metrics import run_eval


class TestClassifyPathUsed(unittest.TestCase):
    def test_face_observation_means_face_path(self):
        result = {"forensicObservations": [
            "Image dimensions: 640x480 (3 color channels).",
            "Face Model (Image) Confidence: 37.9% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FACE)

    def test_full_scene_observation_means_fallback(self):
        result = {"forensicObservations": [
            "Full-Scene Inference (Image): 39.9% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FALLBACK)

    def test_face_wins_over_full_scene_when_both_present(self):
        result = {"forensicObservations": [
            "Full-Scene Inference (Image): 10.0% fake probability.",
            "Face Model (Image) Confidence: 90.0% fake probability.",
        ]}
        self.assertEqual(run_eval.classify_path_used(result), run_eval.FACE)

    def test_missing_observations_is_unknown_not_a_guess(self):
        self.assertEqual(run_eval.classify_path_used({}), "unknown")
        self.assertEqual(run_eval.classify_path_used({"forensicObservations": None}), "unknown")


class TestManifest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write_manifest(self, where: Path, rows):
        where.mkdir(parents=True, exist_ok=True)
        with open(where / "manifest.csv", "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=["path", "label", "split", "video_id", "method"])
            w.writeheader()
            w.writerows(rows)

    def test_manifest_in_root_is_found(self):
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "real" / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp)
        row = run_eval.lookup_manifest(m, self.tmp / "real" / "a.png")
        self.assertEqual(row["video_id"], "v1")

    def test_manifest_in_parent_is_found(self):
        (self.tmp / "val").mkdir()
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "val" / "real" / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp / "val")
        self.assertEqual(run_eval.lookup_manifest(m, self.tmp / "val" / "real" / "a.png")["video_id"], "v1")

    def test_lookup_falls_back_to_filename(self):
        self._write_manifest(self.tmp, [
            {"path": "/somewhere/else/a.png", "label": 0, "split": "val",
             "video_id": "v9", "method": "Deepfakes"},
        ])
        m = run_eval.load_manifest(self.tmp)
        self.assertEqual(run_eval.lookup_manifest(m, Path("C:/other/a.png"))["video_id"], "v9")

    def test_missing_manifest_returns_empty(self):
        self.assertEqual(run_eval.load_manifest(self.tmp), {})
        self.assertEqual(run_eval.lookup_manifest({}, Path("x.png")), {})

    def test_unknown_file_yields_empty_row(self):
        self._write_manifest(self.tmp, [
            {"path": str(self.tmp / "a.png"), "label": 0, "split": "val",
             "video_id": "v1", "method": "original"},
        ])
        m = run_eval.load_manifest(self.tmp)
        self.assertEqual(run_eval.lookup_manifest(m, self.tmp / "zzz.png"), {})


class TestMetricBlocks(unittest.TestCase):
    def test_threshold_is_honoured(self):
        # Every sample scores 0.40: below 0.5 -> all real, above 0.3 -> all fake.
        low = run_eval._metric_block([0, 1], [0.4, 0.4], 0.5)
        self.assertEqual(low["cm"]["tp"], 0)
        self.assertEqual(low["cm"]["fn"], 1)
        high = run_eval._metric_block([0, 1], [0.4, 0.4], 0.3)
        self.assertEqual(high["cm"]["tp"], 1)
        self.assertEqual(high["cm"]["fp"], 1)

    def test_n_is_reported(self):
        block = run_eval._metric_block([0, 1, 0], [0.1, 0.9, 0.2], 0.5)
        self.assertEqual(block["n"], 3)

    def test_small_group_detection(self):
        self.assertTrue(run_eval._too_small(run_eval.MIN_GROUP_ROWS - 1))
        self.assertFalse(run_eval._too_small(run_eval.MIN_GROUP_ROWS))


def _read_source() -> str:
    return Path(run_eval.__file__).read_text(encoding="utf-8")


class _SimulatedCrash(BaseException):
    """A crash the harness must not survive on its own.

    BaseException, not Exception, because ``evaluate_image`` catches Exception
    and records an ERROR row - exactly like a Ctrl-C or a killed process, this
    has to escape and leave the CSV holding only what was really scored.
    """


class _FakePipeline:
    """Stand-in for ImagePipeline.

    Deterministic scores so two runs can be compared byte for byte, plus
    ``fail_at`` to crash after N images - which is what ``--resume`` has to
    pick up from.
    """

    def __init__(self, fail_at=None):
        self.seen = []
        self.fail_at = fail_at

    def process(self, path):
        if self.fail_at is not None and len(self.seen) == self.fail_at:
            raise _SimulatedCrash("simulated interruption")
        name = Path(path).name
        self.seen.append(name)
        pct = 5.0 + (sum(ord(c) for c in name) * 31) % 90
        return {
            "fakeProbability": pct,
            "verdict": "FAKE" if pct >= 50.0 else "AUTHENTIC",
            "forensicObservations": [
                f"Face Model (Image) Confidence: {pct:.1f}% fake probability."
            ],
            "local_fake_probability": pct,
            "rd_fake_probability": None,
            "rd_status": "not_run",
        }


class TestIncrementalWriteAndResume(unittest.TestCase):
    """results.csv must survive an interruption, and --resume must finish the
    run with the same rows an uninterrupted run would have written."""

    def setUp(self):
        import shutil
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.root = self.tmp / "val"
        for sub, prefix, count in (("real", "real", 3), ("fake", "fake", 3)):
            (self.root / sub).mkdir(parents=True)
            for i in range(count):
                (self.root / sub / f"{prefix}_{i}.png").write_bytes(
                    b"\x89PNG\r\n\x1a\n" + f"{prefix}{i}".encode()
                )
        self.csv_path = self.root / "results.csv"
        self.files = (list(run_eval._collect_files(self.root / "real", 0)) +
                      list(run_eval._collect_files(self.root / "fake", 1)))

    def _run(self, pipeline, resume=False, manifest=None, max_frames=8,
             progress_every=25):
        return run_eval.run_evaluation(
            files=self.files,
            manifest=manifest or {},
            pipeline=pipeline,
            csv_path=self.csv_path,
            max_frames_per_video=max_frames,
            resume=resume,
            progress_every=progress_every,
        )

    def _rows(self):
        return run_eval.read_results(self.csv_path)

    def test_header_and_rows_hit_disk_before_the_run_ends(self):
        pipeline = _FakePipeline(fail_at=2)
        with self.assertRaises(_SimulatedCrash):
            self._run(pipeline)

        on_disk = self.csv_path.read_text(encoding="utf-8")
        self.assertTrue(on_disk.startswith("file,label,score,"), on_disk)
        self.assertEqual(len(on_disk.strip().splitlines()), 3)  # header + 2
        self.assertEqual(len(pipeline.seen), 2)

    def test_resume_finishes_the_run(self):
        with self.assertRaises(_SimulatedCrash):
            self._run(_FakePipeline(fail_at=2))
        self._run(_FakePipeline(), resume=True)
        self.assertEqual(len(self._rows()), len(self.files))

    def test_resumed_run_matches_an_uninterrupted_run(self):
        first = _FakePipeline(fail_at=2)
        with self.assertRaises(_SimulatedCrash):
            self._run(first)
        self._run(_FakePipeline(), resume=True)
        resumed_csv = self.csv_path.read_text(encoding="utf-8")
        resumed_names = set(first.seen) | set(self._names())

        # Same starting point, no interruption.
        self.csv_path.unlink()
        whole = _FakePipeline()
        self._run(whole)
        self.assertEqual(resumed_csv, self.csv_path.read_text(encoding="utf-8"))
        self.assertEqual(resumed_names, set(whole.seen))

    def _names(self):
        return {p.name for p, _ in self.files}

    def test_resume_neither_duplicates_nor_rescores(self):
        self._run(_FakePipeline())
        before = self.csv_path.read_text(encoding="utf-8")

        # fail_at=0: any call to process() at all would raise.
        rows = self._run(_FakePipeline(fail_at=0), resume=True)

        self.assertEqual(len(rows), len(self.files))
        self.assertEqual(self.csv_path.read_text(encoding="utf-8"), before)

    def test_fresh_run_truncates_a_stale_results_file(self):
        with self.assertRaises(_SimulatedCrash):
            self._run(_FakePipeline(fail_at=1))
        with self.assertRaises(_SimulatedCrash):
            self._run(_FakePipeline(fail_at=1))
        self._run(_FakePipeline(), resume=False)
        self.assertEqual(len(self._rows()), len(self.files))

    def test_progress_lines_report_done_total_elapsed_and_eta(self):
        import io
        from contextlib import redirect_stdout

        buf = io.StringIO()
        with redirect_stdout(buf):
            self._run(_FakePipeline(), progress_every=2)
        lines = [ln for ln in buf.getvalue().splitlines() if "[PROGRESS]" in ln]

        self.assertEqual(len(lines), 3)  # 6 images, progress_every=2
        self.assertIn("2/6 scored", lines[0])
        for token in ("elapsed", "ETA"):
            self.assertIn(token, lines[0])

    def test_resume_respects_the_frame_cap_across_runs(self):
        manifest = {
            name: {"video_id": "v1", "method": "original"}
            for name in self._names()
        }
        with self.assertRaises(_SimulatedCrash):
            self._run(_FakePipeline(fail_at=1), manifest=manifest, max_frames=2)
        self._run(_FakePipeline(), resume=True, manifest=manifest, max_frames=2)

        self.assertEqual(len(self._rows()), 2)
        self.assertTrue(all(r["video_id"] == "v1" for r in self._rows()))

    def test_metrics_come_from_the_csv_not_from_memory(self):
        import io
        from contextlib import redirect_stdout

        self._run(_FakePipeline())
        rows = self._rows()
        if all(r["score"] >= 0.5 for r in rows) or all(r["score"] < 0.5 for r in rows):
            self.skipTest("synthetic scores are degenerate")

        buf = io.StringIO()
        with redirect_stdout(buf):
            run_eval.report_metrics(rows, 0.5)
        before = buf.getvalue()

        # Rewrite the file: the report must follow it, not the run's memory.
        with open(self.csv_path, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=run_eval.FIELDNAMES)
            writer.writeheader()
            for row in rows:
                perfect = 1.0 if row["label"] == 1 else 0.0
                writer.writerow(dict(row, score=perfect, verdict="FAKE"))

        buf = io.StringIO()
        with redirect_stdout(buf):
            run_eval.report_metrics(run_eval.read_results(self.csv_path), 0.5)

        self.assertNotEqual(before, buf.getvalue())
        self.assertIn("accuracy=1.0000", buf.getvalue())


class TestEngineFlags(unittest.TestCase):
    """The harness must never reach the network unless explicitly asked to."""

    def test_default_engine_is_local(self):
        self.assertIn('default="local"', _read_source())
        self.assertIn('choices=["local", "rd", "fused"]', _read_source())

    def test_local_only_flag_exists(self):
        self.assertIn('"--local-only"', _read_source())

    def test_max_frames_cap_exists(self):
        self.assertIn("--max-frames-per-video", _read_source())

    def test_resume_flag_exists(self):
        self.assertIn('"--resume"', _read_source())

    def test_rows_are_flushed_per_image(self):
        self.assertIn("handle.flush()", _read_source())

    def test_rd_columns_are_written(self):
        for column in ("local_score", "rd_score", "rd_status"):
            self.assertIn(column, _read_source())


if __name__ == "__main__":
    unittest.main()

