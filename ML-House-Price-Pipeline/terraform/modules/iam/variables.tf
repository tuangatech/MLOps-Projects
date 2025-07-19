variable "project_name" {}
variable "environment" {}
variable "s3_buckets" {
  type = object({
    raw_data      = string
    processed_data = string
    feedback_data = string
    dags           = string
    code_bucket    = string
  })
}

/*====
variable "source_bucket_name" {
  description = "Name of the S3 bucket used by MWAA for DAGs"
  type        = string
}
*/