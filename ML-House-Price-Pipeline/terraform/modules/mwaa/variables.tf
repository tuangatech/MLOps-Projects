variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "source_bucket_arn" {
  type = string
}

variable "dag_s3_path" {
  type    = string
  default = "dags/"
}

variable "airflow_role_arn" {
  type = string
}

variable "s3_buckets" {
  type = object({
    raw_data        = string
    processed_data  = string
    feedback_data   = string
    code_bucket     = string
  })
  description = "S3 buckets used across the project"
}

# VPC networking
variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}
