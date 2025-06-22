# MLOps Projects

This repo showcases two end-to-end machine learning deployment pipelines using modern MLOps stacks. Both projects move models from local development into production-ready APIs hosted on AWS infrastructure, with a focus on reproducibility, scalability, and developer control.

---

## 1. End-to-End ML Deployment with MLflow, FastAPI, and AWS Fargate

**Use Case**  
Build and deploy a regression model (XGBoost on California Housing dataset) as a real-time prediction API. The goal is to demonstrate a production-grade pipeline that covers training, model tracking, and serving — without managing EC2 or Kubernetes.

**Tech Stack**  
- **Model**: XGBoost for tabular regression  
- **Experiment Tracking**: MLflow (logs metrics, artifacts, and manages model versions)  
- **Serving**: FastAPI web service with `/predict` endpoint  
- **Infrastructure**:  
  - Dockerized app running on AWS ECS with Fargate (serverless containers)  
  - Terraform for IaC (VPC, ECS, IAM roles, load balancers, etc.)  
- **Model Loading**: Fetches model from S3 at runtime, enabling hot-swaps without image rebuilds  
- **Benefits**: Async inference, Swagger docs, and cost-efficient deployment



## 2. Deploying ML Models to AWS with Docker and SageMaker

**Use Case**  
Convert an intent detection model (RoBERTa fine-tuned with PyTorch) into a real-time API hosted on AWS SageMaker. Ideal for transforming notebook-based ML projects into production-ready services.

**Tech Stack**  
- **Model**: RoBERTa fine-tuned for intent classification  
- **Serving**: Custom inference logic with `inference.py` and `serve.py`  
- **Packaging**:  
  - Custom Docker image (built locally and pushed to AWS ECR)  
  - `Dockerfile` and `requirements.txt` define full runtime environment  
- **Deployment**:  
  - AWS SageMaker for managed model hosting  
  - Terraform and AWS CLI to configure IAM roles, ECR, and secrets  
  - SageMaker SDK for endpoint creation and deployment  
- **Performance**: Supports load testing and response time profiling  
- **Cleanup**: All infra is tear-down-ready to minimize AWS costs

---

📦 Both projects avoid click-ops in the AWS Console — everything is code-driven, automatable, and production-aligned.
