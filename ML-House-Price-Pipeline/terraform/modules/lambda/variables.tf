variable "project_name" {}
variable "environment" {}
variable "lambda_role_arn" {}
variable "lambda_role_name" {}

variable "s3_buckets" {
  type = object({
    raw_data      = string
    processed_data = string
    feedback_data = string
    lambdas       = string 
  })
}
variable "prediction_table_name" {}

variable "lambda_runtime" {}