import os
import logging
from typing import Optional
from config import config as app_config

logger = logging.getLogger("veriframe.models")

class ModelExporter:
    @staticmethod
    def export_to_tflite(source_model_path: str, output_path: str, input_shape: tuple = (1, 224, 224, 3)) -> str:
        try:
            import tensorflow as tf
            logger.info(f"[ModelExporter] Converting {source_model_path} to TFLite")
            model = tf.keras.models.load_model(source_model_path)
            converter = tf.lite.TFLiteConverter.from_keras_model(model)
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            if app_config.USE_GPU_DELEGATE:
                converter.target_spec.supported_types = [tf.float16]
            tflite_model = converter.convert()
            with open(output_path, "wb") as f:
                f.write(tflite_model)
            logger.info(f"[ModelExporter] Saved TFLite model to {output_path}")
            return output_path
        except Exception as e:
            logger.error(f"[ModelExporter] TFLite export failed: {e}")
            raise

    @staticmethod
    def validate_tflite(model_path: str) -> dict:
        try:
            import tensorflow as tf
            interpreter = tf.lite.Interpreter(model_path=model_path)
            interpreter.allocate_tensors()
            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()
            return {
                "valid": True,
                "input_shape": input_details[0]["shape"].tolist(),
                "output_shape": output_details[0]["shape"].tolist(),
                "input_dtype": str(input_details[0]["dtype"]),
                "output_dtype": str(output_details[0]["dtype"]),
            }
        except Exception as e:
            return {"valid": False, "error": str(e)}

    @staticmethod
    def get_model_info(model_path: str) -> dict:
        size_bytes = os.path.getsize(model_path) if os.path.exists(model_path) else 0
        validation = ModelExporter.validate_tflite(model_path)
        return {
            "path": model_path,
            "size_mb": round(size_bytes / (1024 * 1024), 2),
            "validation": validation,
        }