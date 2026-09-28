import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.score_utils import normalize_score_0_1


class TestNormalizeScore(unittest.TestCase):
    """The helper must collapse both documented RD scales (0-1 and 0-100) onto 0-1."""

    def test_fraction_passes_through(self):
        self.assertAlmostEqual(normalize_score_0_1(0.0), 0.0)
        self.assertAlmostEqual(normalize_score_0_1(0.45), 0.45)
        self.assertAlmostEqual(normalize_score_0_1(1.0), 1.0)

    def test_percent_is_divided(self):
        self.assertAlmostEqual(normalize_score_0_1(45.0), 0.45)
        self.assertAlmostEqual(normalize_score_0_1(62.5), 0.625)
        self.assertAlmostEqual(normalize_score_0_1(100.0), 1.0)

    def test_ambiguous_band_is_read_as_fraction(self):
        # 0.45 from rd-context-img is already a fraction, not 0.45%.
        self.assertAlmostEqual(normalize_score_0_1(0.45), 0.45)
        # Exactly on the boundary belongs to the fraction side of the rule.
        self.assertAlmostEqual(normalize_score_0_1(1.0), 1.0)

    def test_assume_percent_overrides_the_band_rule(self):
        self.assertAlmostEqual(normalize_score_0_1(0.45, assume_percent=True), 0.0045)
        self.assertAlmostEqual(normalize_score_0_1(1.0, assume_percent=True), 0.01)

    def test_missing_and_invalid_values_return_none(self):
        for value in (None, "", "n/a", [], {}):
            self.assertIsNone(normalize_score_0_1(value))

    def test_nan_returns_none(self):
        self.assertIsNone(normalize_score_0_1(float("nan")))

    def test_out_of_range_is_clamped(self):
        self.assertAlmostEqual(normalize_score_0_1(-5.0), 0.0)
        self.assertAlmostEqual(normalize_score_0_1(450.0), 1.0)
        self.assertAlmostEqual(normalize_score_0_1(150.0), 1.0)

    def test_booleans(self):
        self.assertAlmostEqual(normalize_score_0_1(True), 1.0)
        self.assertAlmostEqual(normalize_score_0_1(False), 0.0)

    def test_numeric_strings(self):
        self.assertAlmostEqual(normalize_score_0_1("73"), 0.73)

    def test_mixed_panel_averages_consistently(self):
        # A panel mixing a percent model and a fraction model must land on the
        # same 0-1 scale, otherwise the average is off by up to 100x.
        percent_model = normalize_score_0_1(80.0)
        fraction_model = normalize_score_0_1(0.20)  # rd-context-img style
        self.assertAlmostEqual(percent_model, 0.80)
        self.assertAlmostEqual(fraction_model, 0.20)
        self.assertAlmostEqual((percent_model + fraction_model) / 2, 0.50)


class TestRealityDefenderIncompleteModels(unittest.TestCase):
    def setUp(self):
        from detectors.reality_defender_detector import models_still_analyzing

        self.fn = models_still_analyzing

    def test_analyzing_models_are_listed(self):
        models = [
            {"name": "rd-image-ensemble", "status": "AUTHENTIC", "score": 3.0},
            {"name": "rd-context-img", "status": "ANALYZING", "score": None},
            {"name": "rd-genimg-detector", "status": "DOWNLOADING", "score": None},
        ]
        self.assertEqual(self.fn(models), ["rd-context-img", "rd-genimg-detector"])

    def test_settled_panel_returns_empty(self):
        models = [
            {"name": "rd-image-ensemble", "status": "AUTHENTIC", "score": 3.0},
            {"name": "rd-context-img", "status": "AUTHENTIC", "score": 0.45},
        ]
        self.assertEqual(self.fn(models), [])

    def test_non_list_input(self):
        self.assertEqual(self.fn(None), [])
        self.assertEqual(self.fn("nope"), [])


class TestRealityDefenderPartialVerdict(unittest.TestCase):
    """A partial cloud result must never produce a firm verdict."""

    def setUp(self):
        from services.reality_defender_service import RealityDefenderService

        self.service = RealityDefenderService.__new__(RealityDefenderService)

    def _partial(self, incomplete):
        return self.service._normalize({
            "status": "success",
            "request_id": "req-partial",
            "score": 0.02,
            "rd_status": "AUTHENTIC",
            "partial": True,
            "incomplete_models": incomplete,
            "models": [{"name": "rd-image-ensemble", "status": "AUTHENTIC", "score": 2.0}],
        })

    def test_partial_authentic_is_downgraded(self):
        out = self._partial(["rd-context-img"])
        self.assertEqual(out["verdict"], "INCONCLUSIVE")
        self.assertEqual(out["fine_verdict"], "UNCERTAIN")
        self.assertTrue(out["partial"])
        self.assertEqual(out["incomplete_models"], ["rd-context-img"])
        self.assertEqual(out["evidence"], [])

    def test_partial_manipulated_is_downgraded(self):
        raw = {
            "status": "success",
            "request_id": "req-partial-2",
            "score": 0.97,
            "rd_status": "MANIPULATED",
            "partial": True,
            "incomplete_models": ["rd-voice-cloning"],
            "models": [],
        }
        out = self.service._normalize(raw)
        self.assertEqual(out["verdict"], "INCONCLUSIVE")
        self.assertEqual(out["fine_verdict"], "UNCERTAIN")

    def test_partial_confidence_is_lowered(self):
        full = self.service._normalize({
            "status": "success", "request_id": "r", "score": 0.9,
            "rd_status": "MANIPULATED", "confidence": 80.0, "models": [],
        })
        partial = self.service._normalize({
            "status": "success", "request_id": "r", "score": 0.9,
            "rd_status": "MANIPULATED", "confidence": 80.0, "partial": True,
            "incomplete_models": ["m1"], "models": [],
        })
        self.assertEqual(full["verdict"], "MANIPULATED")
        self.assertLess(partial["confidence"], full["confidence"])

    def test_model_scores_normalized_before_thresholding(self):
        out = self.service._normalize({
            "status": "success", "request_id": "r", "score": 0.1,
            "rd_status": "AUTHENTIC", "models": [
                {"name": "rd-context-img", "status": "AUTHENTIC", "score": 0.45},
                {"name": "rd-genimg-detector", "status": "MANIPULATED", "score": 82.0},
            ],
        })
        joined = " ".join(out["evidence"] + out["observations"])
        # 0.45 is a fraction -> 45.0%; 82.0 is a percent -> 82.0%.
        self.assertIn("45.0%", joined)
        self.assertIn("82.0%", joined)
        self.assertNotIn("(0.45%)", joined)
        self.assertTrue(any("rd-genimg-detector" in e for e in out["evidence"]))
        self.assertFalse(any("rd-context-img" in e for e in out["evidence"]))


if __name__ == "__main__":
    unittest.main()
