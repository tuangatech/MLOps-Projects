import os
import json
import joblib
import torch
import logging
import traceback
from transformers import RobertaTokenizer
from model import IntentClassifier, configs
from utils import preprocess_text

# Configuration - should match your training setup
NUM_CLASSES = 27
MAX_LEN = 60  # Update to match your training config

# Set device (GPU if available, else CPU)
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"> Device: {device}")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def model_fn(model_dir):
    """Load model and assets from model package"""
    try:
        # Load model
        model_path = os.path.join(model_dir, "model.pth")
        logger.info(f"Loading model from: {model_path}")
        model = IntentClassifier(num_intent_classes=NUM_CLASSES)
        checkpoint = torch.load(model_path, map_location=device)
        model.load_state_dict(checkpoint["model_state_dict"])
        model.to(device).eval()
        
        # Load label encoder from package
        label_encoder_path = os.path.join(model_dir, "label_encoder.pkl")
        label_encoder = joblib.load(label_encoder_path)
        logger.info(f"Loading label_encoder from: {label_encoder_path}")
        
        # Load tokenizer
        tokenizer = RobertaTokenizer.from_pretrained(configs.model_name)
        logger.info("Model loaded successfully")
        
        return {
            "model": model,
            "label_encoder": label_encoder,
            "tokenizer": tokenizer
        }
        
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        logger.error(traceback.format_exc())
        raise RuntimeError(f"Failed to load model: {str(e)}")

def input_fn(input_data, content_type):
    logger.info(f"Processing input with content type: {content_type}")
    logger.debug(f"Input body: {input_data}")
    """Parse input data"""
    if content_type != "application/json":
        raise ValueError(f"Unsupported content type: {content_type}")
    
    data = json.loads(input_data)
    return data["texts"]

def predict_fn(texts, artifacts):
    """Perform prediction"""
    model = artifacts["model"]
    label_encoder = artifacts["label_encoder"]
    tokenizer = artifacts["tokenizer"]
    
    intents = []
    for text in texts:
        processed_text = preprocess_text(text)
        logger.info(f"> Preprocessed from {text} -> {processed_text}")
        # Tokenize input
        inputs = tokenizer(
            processed_text,
            max_length=MAX_LEN,
            padding="max_length",
            truncation=True,
            return_tensors="pt"
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        # Predict
        with torch.no_grad():
            outputs = model(**inputs)
            _, pred = torch.max(outputs.logits, 1)
            pred_label = label_encoder.inverse_transform([pred.cpu().item()])[0]
        
        intents.append(pred_label)
    
    return intents

def output_fn(prediction, accept):
    """Format output"""
    if accept == "application/json":
        return json.dumps({"intents": prediction})
    raise ValueError(f"Unsupported accept type: {accept}")