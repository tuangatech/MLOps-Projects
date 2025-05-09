import os
import logging
import tempfile
import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import mlflow.pyfunc
import pandas as pd

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables + default values
MODEL_BUCKET_NAME = os.getenv("MODEL_BUCKET_NAME", "s3-ttran-models")  # set in ECS.tf
MODEL_PATH = os.getenv("MODEL_PATH", "mlflow/models/california-housing/5")

# Initialize FastAPI app
app = FastAPI(
    title="California Housing Price Predictor",
    description="Predict housing prices using XGBoost model trained on California dataset",
    version="1.0"
)

# Global variable to hold model
model = None

@app.on_event("startup")
def load_model():
    global model
    logger.info("Starting up and loading MLflow model...")

    s3_client = boto3.client("s3")
    temp_dir = "/tmp/model"

    try:
        logger.info(f"Loading model directly from s3://{MODEL_BUCKET_NAME}/{MODEL_PATH}")
        
        # Load directly from S3
        model_uri = f"s3://{MODEL_BUCKET_NAME}/{MODEL_PATH}"
        model = mlflow.pyfunc.load_model(model_uri)
        logger.info("Model loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise

# Input schema
class HousingData(BaseModel):
    MedInc: float
    HouseAge: float
    AveRooms: float
    AveBedrms: float
    Population: float
    AveOccup: float
    Latitude: float
    Longitude: float

# Prediction endpoint
@app.post("/predict")
def predict(data: HousingData):
    try:
        print(f"Received data: {data}")
        # Ensure the model is loaded   
        if model is None:
                raise HTTPException(status_code=500, detail="Model not loaded")
        
        input_df = pd.DataFrame([data.dict()])  # Convert to named-column DataFrame
        prediction = model.predict(input_df)
        return {"prediction": float(prediction[0])}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Health check endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/ready")
def readiness_check():
    """Readiness probe: checks if model is loaded and usable"""
    global model
    logger.info("Running readiness check...")
    
    if model is None:
        logger.error("Model not loaded")
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        # Optional: run a quick inference test
        sample_input = pd.DataFrame([{
            "MedInc": 8.0,
            "HouseAge": 40.0,
            "AveRooms": 8.0,
            "AveBedrms": 2.0,
            "Population": 800.0,
            "AveOccup": 3.0,
            "Latitude": 35.0,
            "Longitude": -122.0
        }])
        prediction = model.predict(sample_input)
        logger.info(f"Sample prediction: {prediction[0]}")
    except Exception as e:
        logger.error(f"Model validation failed: {e}")
        raise HTTPException(status_code=503, detail=f"Model validation failed: {e}")

    return {"status": "ready"}