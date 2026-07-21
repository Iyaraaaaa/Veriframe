import numpy as np
from typing import Dict, List, Tuple
import logging

logger = logging.getLogger("veriframe.metrics")

class MetricsEvaluator:
    @staticmethod
    def compute_confusion_matrix(y_true: np.ndarray, y_pred: np.ndarray, threshold: float = 0.5) -> Dict[str, int]:
        preds = (y_pred >= threshold).astype(int)
        tp = int(np.sum((y_true == 1) & (preds == 1)))
        tn = int(np.sum((y_true == 0) & (preds == 0)))
        fp = int(np.sum((y_true == 0) & (preds == 1)))
        fn = int(np.sum((y_true == 1) & (preds == 0)))
        return {"tp": tp, "tn": tn, "fp": fp, "fn": fn}

    @staticmethod
    def compute_metrics(y_true: np.ndarray, y_pred: np.ndarray, threshold: float = 0.5) -> Dict[str, float]:
        cm = MetricsEvaluator.compute_confusion_matrix(y_true, y_pred, threshold)
        tp, tn, fp, fn = cm["tp"], cm["tn"], cm["fp"], cm["fn"]

        accuracy = (tp + tn) / max(tp + tn + fp + fn, 1)
        precision = tp / max(tp + fp, 1)
        recall = tp / max(tp + fn, 1)
        f1 = 2 * precision * recall / max(precision + recall, 1e-6)
        fpr = fp / max(fp + tn, 1)
        fnr = fn / max(fn + tp, 1)

        try:
            from sklearn.metrics import roc_auc_score
            auc = float(roc_auc_score(y_true, y_pred))
        except Exception:
            auc = 0.0

        return {
            "accuracy": round(accuracy, 4),
            "precision": round(precision, 4),
            "recall": round(recall, 4),
            "f1_score": round(f1, 4),
            "fpr": round(fpr, 4),
            "fnr": round(fnr, 4),
            "auc": round(auc, 4),
            "confusion_matrix": cm,
        }

    @staticmethod
    def compute_video_level_metrics(frame_scores: List[float], video_labels: List[int]) -> Dict[str, float]:
        if not frame_scores or not video_labels:
            return {}
        video_preds = []
        for scores in frame_scores:
            avg = float(np.mean(scores))
            video_preds.append(avg)
        return MetricsEvaluator.compute_metrics(
            np.array(video_labels), np.array(video_preds)
        )
