import numpy as np
import logging
from typing import List, Dict, Any, Tuple

logger = logging.getLogger("veriframe.detectors.face_tracker")

class TrackedFace:
    def __init__(self, face_id: int, initial_box: Tuple[int, int, int, int], first_frame_idx: int):
        self.face_id = face_id
        self.box = initial_box
        self.first_frame_idx = first_frame_idx
        self.last_frame_idx = first_frame_idx
        self.total_appearances = 1
        self.history_boxes = [initial_box]
        self.history_crops = []
        self.quality_scores = []
        self.detectors_used = []

    @property
    def area(self) -> int:
        return self.box[2] * self.box[3]

    @property
    def centroid(self) -> Tuple[float, float]:
        return (self.box[0] + self.box[2] / 2.0, self.box[1] + self.box[3] / 2.0)

    def update(self, box: Tuple[int, int, int, int], frame_idx: int, crop: np.ndarray, quality: float, detector: str):
        self.box = box
        self.last_frame_idx = frame_idx
        self.total_appearances += 1
        self.history_boxes.append(box)
        self.history_crops.append(crop)
        self.quality_scores.append(quality)
        self.detectors_used.append(detector)

class FaceTracker:
    """Stage 6 & Live Stream Stage 4 — Continuous Face Tracking Engine"""

    def __init__(self, iou_threshold: float = 0.3, max_disappeared: int = 15):
        self.iou_threshold = iou_threshold
        self.max_disappeared = max_disappeared
        self.next_face_id = 1
        self.active_tracks: Dict[int, TrackedFace] = {}

    def reset(self):
        self.next_face_id = 1
        self.active_tracks.clear()

    def update_tracks(
        self,
        frame_idx: int,
        detections: List[Any],
        frame_shape: Tuple[int, int, int]
    ) -> List[Tuple[int, Any]]:
        """
        Matches incoming face detections to existing persistent tracks or creates new face IDs.
        Returns list of (face_id, detection_object).
        """
        matched_results = []
        if not detections:
            return matched_results

        active_ids = list(self.active_tracks.keys())
        if not active_ids:
            # Initialize new tracks for all detections
            for det in detections:
                fid = self.next_face_id
                self.next_face_id += 1
                tf = TrackedFace(fid, det.box, frame_idx)
                tf.update(det.box, frame_idx, det.face_crop, det.quality_score, det.detector)
                self.active_tracks[fid] = tf
                matched_results.append((fid, det))
            return matched_results

        # Compute IoU matrix between existing active tracks and new detections
        iou_matrix = np.zeros((len(active_ids), len(detections)), dtype=np.float32)
        for i, fid in enumerate(active_ids):
            track_box = self.active_tracks[fid].box
            for j, det in enumerate(detections):
                iou_matrix[i, j] = self._compute_iou(track_box, det.box)

        assigned_tracks = set()
        assigned_dets = set()

        # Greedy IoU assignment
        while True:
            if iou_matrix.size == 0:
                break
            max_val = np.max(iou_matrix)
            if max_val < self.iou_threshold:
                break
            i, j = np.unravel_index(np.argmax(iou_matrix), iou_matrix.shape)
            fid = active_ids[i]

            self.active_tracks[fid].update(
                detections[j].box,
                frame_idx,
                detections[j].face_crop,
                detections[j].quality_score,
                detections[j].detector
            )
            matched_results.append((fid, detections[j]))
            assigned_tracks.add(i)
            assigned_dets.add(j)

            # Suppress assigned row/col
            iou_matrix[i, :] = -1.0
            iou_matrix[:, j] = -1.0

        # Unassigned detections get new track IDs
        for j, det in enumerate(detections):
            if j not in assigned_dets:
                fid = self.next_face_id
                self.next_face_id += 1
                tf = TrackedFace(fid, det.box, frame_idx)
                tf.update(det.box, frame_idx, det.face_crop, det.quality_score, det.detector)
                self.active_tracks[fid] = tf
                matched_results.append((fid, det))

        return matched_results

    def filter_primary_faces(self, min_appearances: int = 1) -> List[TrackedFace]:
        """Filters out transient background faces, retaining primary faces with sufficient area & presence."""
        if not self.active_tracks:
            return []

        all_tracks = list(self.active_tracks.values())
        # Sort by total appearances * face area (screen coverage) descending
        all_tracks.sort(key=lambda t: t.total_appearances * t.area, reverse=True)

        # Primary face is top candidate; retain up to 3 major faces
        primary_tracks = [t for t in all_tracks if t.total_appearances >= min_appearances][:3]
        return primary_tracks

    @staticmethod
    def _compute_iou(boxA: Tuple[int, int, int, int], boxB: Tuple[int, int, int, int]) -> float:
        xA = max(boxA[0], boxB[0])
        yA = max(boxA[1], boxB[1])
        xB = min(boxA[0] + boxA[2], boxB[0] + boxB[2])
        yB = min(boxA[1] + boxA[3], boxB[1] + boxB[3])

        interArea = max(0, xB - xA) * max(0, yB - yA)
        boxAArea = boxA[2] * boxA[3]
        boxBArea = boxB[2] * boxB[3]

        denom = float(boxAArea + boxBArea - interArea)
        return interArea / denom if denom > 0 else 0.0
