import os
import json
import logging
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
from datetime import datetime

logger = logging.getLogger("veriframe.models")

SUPPORTED_ARCHITECTURES = [
    "efficientvit",
    "crossefficientvit",
    "efficientnetv2",
    "convnext",
]

@dataclass
class TrainingConfig:
    architecture: str = "efficientvit"
    variant: str = "b0"
    input_size: int = 224
    epochs: int = 30
    batch_size: int = 32
    learning_rate: float = 1e-4
    weight_decay: float = 1e-5
    use_mixup: bool = True
    use_cutmix: bool = True
    use_focal_loss: bool = True
    label_smoothing: float = 0.1
    early_stopping_patience: int = 5
    mixed_precision: bool = True
    output_dir: str = "./model_output"
    datasets: List[str] = field(default_factory=lambda: ["FaceForensics++", "Celeb-DF v2"])

    def validate(self) -> List[str]:
        errors = []
        if self.architecture not in SUPPORTED_ARCHITECTURES:
            errors.append(f"Unsupported architecture: {self.architecture}. Choose from {SUPPORTED_ARCHITECTURES}")
        if self.input_size not in [224, 256, 384, 512]:
            errors.append(f"Input size {self.input_size} not supported. Use 224, 256, 384, or 512")
        if self.epochs < 1:
            errors.append("Epochs must be >= 1")
        if self.batch_size < 1:
            errors.append("Batch size must be >= 1")
        return errors

    def to_dict(self) -> Dict[str, Any]:
        return {
            "architecture": self.architecture,
            "variant": self.variant,
            "input_size": self.input_size,
            "epochs": self.epochs,
            "batch_size": self.batch_size,
            "learning_rate": self.learning_rate,
            "weight_decay": self.weight_decay,
            "use_mixup": self.use_mixup,
            "use_cutmix": self.use_cutmix,
            "use_focal_loss": self.use_focal_loss,
            "label_smoothing": self.label_smoothing,
            "early_stopping_patience": self.early_stopping_patience,
            "mixed_precision": self.mixed_precision,
            "output_dir": self.output_dir,
            "datasets": self.datasets,
        }

class ModelTrainer:
    def __init__(self, config: Optional[TrainingConfig] = None):
        self.config = config or TrainingConfig()
        self.history: Dict[str, List[float]] = {
            "train_loss": [],
            "val_loss": [],
            "train_acc": [],
            "val_acc": [],
        }

    def train(self) -> Dict[str, Any]:
        errors = self.config.validate()
        if errors:
            raise ValueError(f"Invalid training config: {'; '.join(errors)}")

        logger.info(f"[ModelTrainer] Starting training: {self.config.architecture} {self.config.variant}")
        logger.info(f"[ModelTrainer] Datasets: {self.config.datasets}")
        logger.info(f"[ModelTrainer] Epochs: {self.config.epochs}, Batch: {self.config.batch_size}, LR: {self.config.learning_rate}")

        os.makedirs(self.config.output_dir, exist_ok=True)
        config_path = os.path.join(self.config.output_dir, "training_config.json")
        with open(config_path, "w") as f:
            json.dump(self.config.to_dict(), f, indent=2)

        logger.info(f"[ModelTrainer] Training config saved to {config_path}")
        logger.info("[ModelTrainer] Training pipeline initialized. Connect your PyTorch/TensorFlow training loop here.")

        return {
            "status": "initialized",
            "config": self.config.to_dict(),
            "message": "Training pipeline ready. Integrate with your training framework.",
        }

    def export_to_tflite(self, model_path: str, output_path: Optional[str] = None) -> str:
        if output_path is None:
            output_path = os.path.join(self.config.output_dir, "veriframe_model.tflite")

        logger.info(f"[ModelTrainer] Exporting {model_path} to TFLite: {output_path}")
        logger.info("[ModelTrainer] TFLite export requires TensorFlow/PyTorch integration.")
        return output_path

    def get_supported_architectures(self) -> List[str]:
        return SUPPORTED_ARCHITECTURES.copy()

    def get_training_summary(self) -> Dict[str, Any]:
        return {
            "config": self.config.to_dict(),
            "history": self.history,
            "best_val_acc": max(self.history.get("val_acc", [0.0])) if self.history.get("val_acc") else 0.0,
        }