variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "s3_buckets" {
  type = object({
    raw_data       = string
    processed_data = string
    feedback_data  = string
  })
}

variable "sagemaker_execution_role_arn" {
  type = string
}