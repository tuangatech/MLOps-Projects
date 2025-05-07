#!/bin/bash

# === Configuration ===
PROJECT_NAME="california-housing-api"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
ECR_REPO_NAME=$PROJECT_NAME
MODEL_BUCKET_NAME="s3-ttran-models"
MODEL_PATH="mlflow/models/california-housing/5"

# === Build & Push Image ===
IMAGE_NAME=$ECR_REPO_NAME
ECR_REPO_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "ECR Repo URL: $ECR_REPO_URL"
echo "Model Bucket: $MODEL_BUCKET_NAME"
echo "Model Path: $MODEL_PATH"

# Export env vars for Docker build args
export MODEL_BUCKET_NAME
export MODEL_PATH

# Step 1: Build with build args
echo "Building Docker image..."
docker build \
  --no-cache \
  --build-arg MODEL_BUCKET_NAME=$MODEL_BUCKET_NAME \
  --build-arg MODEL_PATH=$MODEL_PATH \
  -t $IMAGE_NAME \
  -f docker/Dockerfile .

# Step 2: Tag with ECR repo URL
echo "Tagging image..."
docker tag $IMAGE_NAME:latest $ECR_REPO_URL:latest

# Step 3: Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Step 4: Push image to ECR
echo "Pushing image to ECR..."
docker push $ECR_REPO_URL:latest

echo "Image pushed to $ECR_REPO_URL:latest"