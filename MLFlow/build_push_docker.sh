#!/bin/bash

# === Configuration ===
ECR_REPO_NAME="california-housing-api"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

# === Build & Push Image ===
IMAGE_NAME=$ECR_REPO_NAME
ECR_REPO_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "ECR Repo URL: $ECR_REPO_URL"

# Step 1: Build and tag Docker image
# 2 tags: one for local use, one for ECR
echo "Building and tagging Docker image..."
docker build  --no-cache \
  -t $IMAGE_NAME -t $ECR_REPO_URL:latest \
  -f docker/Dockerfile .

# Step 2: Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login \
  --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Step 3: Push image to ECR
echo "Pushing image to ECR..."
docker push $ECR_REPO_URL:latest

echo "Image pushed to $ECR_REPO_URL:latest"