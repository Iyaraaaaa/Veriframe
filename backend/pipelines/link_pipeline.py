import logging
from typing import Dict, Any, Optional

from detectors.face_detector import FaceDetector
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from pipelines.link_verification_v2 import LinkVerificationV2

logger = logging.getLogger("veriframe.pipelines.link")

class LinkPipeline:
    """
    Video Link Verification Pipeline (Proxied to LinkVerificationV2).
    Dedicated pipeline for verifying video content from web links and URLs.
    Performs actual video analysis, media decoding, adaptive frame sampling,
    and biometric deepfake detection while strictly separating URL security.
    """
    def __init__(
        self,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        frame_sampler: AdaptiveFrameSampler,
        quality_filter: QualityFilter,
        temporal_filter: TemporalFilter,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
    ):
        self.v2_pipeline = LinkVerificationV2(
            interpreter=interpreter,
            input_details=input_details,
            output_details=output_details,
            face_detector=face_detector,
            frame_sampler=frame_sampler,
            quality_filter=quality_filter,
            temporal_filter=temporal_filter,
            calibrator=calibrator,
            preprocessor=preprocessor,
        )

    def process(self, url: str, source: str = "Video Link", status_cb=None) -> Dict[str, Any]:
        return self.v2_pipeline.process(url, source=source, status_cb=status_cb)
