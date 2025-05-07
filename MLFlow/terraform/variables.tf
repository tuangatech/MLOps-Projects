variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "california-housing-api"
}

variable "region" {
  description = "AWS region to deploy"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

# S3 bucket name where MLflow model is stored
variable "model_bucket_name" {
  description = "Name of the S3 bucket containing MLflow model artifacts"
  type        = string
  default     = "s3-ttran-models"
}

# Path inside S3 bucket to the MLflow model
variable "model_path" {
  description = "Path to MLflow model inside the S3 bucket"
  type        = string
  default     = "mlflow/models/california-housing/5"
}