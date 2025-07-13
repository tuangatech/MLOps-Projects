# End-to-End ML System for Housing Price Prediction: From Ingestion to Retraining

## Introduction
Deploying a machine learning model is easy — maintaining it in production is the real challenge. Models degrade over time, new data drifts, and user behavior changes. Without a solid end-to-end (E2E) lifecycle, even the best models go stale.

In this blog post, we’ll walk through how to build a complete ML production system for predicting housing prices using the Kaggle House Prices: Advanced Regression dataset.

We’re not just training a model here. I’ll show you how to:
- Clean and transform data with SageMaker Processing Jobs
- Train models using SageMaker Training Jobs
- Track experiments and model versions with MLflow
- Deploy and serve predictions via SageMaker Endpoints
- Simulate feedback and monitor model performance over time
- Automatically retrain when performance drops

This post is hands-on and realistic. It combines AWS services like SageMaker, MWAA (Airflow), CloudWatch, Lambda, and DynamoDB — all orchestrated to self-heal your ML pipeline when things drift.

Let’s dive into the system design.

## High-Level Solution
### Business Goal
Build a production-grade ML system that:
- Predicts house prices using a regression model
- Ingests real-world-like data every 15 minutes
- Monitors performance and automatically retrains if needed
- Improves over time using feedback loops

### Technical Architecture Overview
The solution is broken down into modular, scalable components:

**1. Data Ingestion**
- Training data: Upload Kaggle’s `train.csv` to `s3://raw-data/training/`
- Inference data: Split `test.csv` into batches, upload to `s3://raw-data/inference/` every 15 minutes via Lambda + EventBridge
- Simulated feedback: Add 7% noise to predicted prices to fake real-world actuals

**2. Data Processing**
- Use MWAA (Airflow) to trigger SageMaker Processing Jobs
- Clean/transform training and inference data (handle missing values, encode features)
- Save processed data to:
  - `s3://processed-data/training/`
  - `s3://processed-data/inference/`

**3. Model Training**
- Initial training on clean Kaggle data
- Retraining uses feedback data (features + simulated actual prices)
- Combine old + new data for stability (avoids forgetting trends)

**4. Experiment Tracking**
- Use MLflow for:
  - Logging RMSE, R², MAE
  - Versioning models
  - Registering models that meet deployment criteria (e.g., R² ≥ 0.85)

**5. Deployment**
- Use SageMaker Endpoints for real-time inference
- Optionally secure with API Gateway + Cognito
- Predictions stored in DynamoDB, actuals simulated with noise

**6. Monitoring & Alerts**
- Use SageMaker Model Monitor for drift and quality detection
- Use CloudWatch for latency, error rates, and alarm triggering
- Trigger Lambda when thresholds break (e.g., R² < 0.85) → call Airflow DAG

**7. Feedback Loop & Auto-Retraining**
- Simulate real prices like the system get live data from real world. Save predicted and (simulated) actual prices into DynamoDB for drift detection.
- If performance drops:
  - Lambda checks MLflow metrics
  - Triggers Airflow DAG
  - DAG runs retraining and deployment pipeline
  - Feedback (inference features + actuals) pulled from s3://feedback-data/

**8. Observability Dashboard**
- Use Grafana to visualize:
  - Model performance (R² over time)
  - Inference latency, error rates
  - Drift detection results from Model Monitor
  - CloudWatch logs + MLflow model versions

