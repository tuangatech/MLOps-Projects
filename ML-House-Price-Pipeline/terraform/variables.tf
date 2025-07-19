variable "project_name" {
  description = "Name of the project used as prefix"
  type        = string
  default     = "housing-price-prediction"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "lambda_runtime" {
  description = "Runtime version for Lambda functions"
  type        = string
  default     = "python3.11"
}

variable "sagemaker_instance_type" {
  description = "Instance type for SageMaker Processing/Training jobs"
  type        = string
  default     = "ml.t3.medium"
}