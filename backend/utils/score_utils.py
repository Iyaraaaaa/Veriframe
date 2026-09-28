"""
Single source of truth for score-scale normalization.

The backend mixes producers that use two different scales:

* **0-1 fractions** - every local TFLite output (``veriframe_model.tflite``,
  ``Image.tflite``, ``Audio.tflite``) and the scene/temporal filters.
* **0-100 percentages** - the Reality Defender API. The SDK divides
  ``resultsSummary.metadata.finalScore`` by 100 for the top-level score, but it
  forwards each model's ``predictionNumber`` **raw and unscaled**.

Reality Defender is not consistent even about its own per-model scores: the
``rd-context-img`` model, for example, returns ``0.45`` where the documented
scale is 0-100, i.e. it returns a 0-1 fraction. Averaging or displaying those
two shapes together without a rule silently produces scores that are wrong by
up to 100x.

Normalize every score with :func:`normalize_score_0_1` before averaging,
thresholding or rendering it.
"""

from typing import Any, Optional

# Scores greater than this are unambiguously percentages. Scores at or below
# this are the ambiguous band and are handled by the rule documented on
# ``normalize_score_0_1``.
PERCENT_SCALE_FLOOR = 1.0


def normalize_score_0_1(value: Any, *, assume_percent: bool = False) -> Optional[float]:
    """Return ``value`` as a float on the 0.0 - 1.0 scale, or ``None``.

    Resolution rule, in order:

    1. ``None`` / blank / non-numeric -> ``None``. A missing score is never
       silently coerced to "0% fake".
    2. ``assume_percent=True`` -> always read as 0-100 and divide by 100.
       Use this when the producer is known to be percentage-based and the
       payload cannot be trusted (e.g. a hand-written or third-party payload).
    3. ``value > 1.0`` -> read as 0-100, divide by 100. This is the documented
       Reality Defender ``predictionNumber`` scale.
    4. ``1.0 >= value >= 0.0`` -> **the ambiguous band**: already a 0-1
       fraction, returned unchanged.

       The rule for the ambiguous band is "a value at or below 1.0 is a
       fraction, not a percentage". The payload is genuinely ambiguous here -
       ``0.45`` may mean 45% or 0.45% - and no arithmetic can disambiguate it.
       A fraction reading is chosen because the two readings differ only
       inside a band where they produce the same verdict anyway (both land far
       below the 30% "authentic" threshold), whereas the percentage reading
       would turn an ordinary 0.0045 fraction into a 45% "manipulated" score.
       Forcing a percentage reading risks manufacturing a fake-positive verdict
       out of a score that is already normalized; the fraction reading cannot
       invent a verdict. The known offenders (e.g. ``rd-context-img``) are
       fraction-returning, so the rule also matches observed behaviour.
    5. Out-of-range input is clamped to 0.0 - 1.0 after conversion, so a
       mis-scaled 450.0 becomes a definite 1.0 rather than an out-of-bounds
       score.
    """
    if value is None:
        return None
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    try:
        score = float(value)
    except (TypeError, ValueError):
        return None
    if score != score:  # NaN
        return None

    if assume_percent:
        score = score / 100.0
    elif score > PERCENT_SCALE_FLOOR:
        score = score / 100.0

    if score < 0.0:
        return 0.0
    if score > 1.0:
        return 1.0
    return score
