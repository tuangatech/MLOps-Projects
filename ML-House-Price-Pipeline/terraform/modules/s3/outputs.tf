output "raw_data_bucket" {
  value = aws_s3_bucket.raw_data_bucket.id
}

output "processed_data_bucket" {
  value = aws_s3_bucket.processed_data_bucket.id
}

output "feedback_data_bucket" {
  value = aws_s3_bucket.feedback_data_bucket.id
}

output "code_bucket" {
  value = aws_s3_bucket.code_bucket.bucket
}

/* ======
output "mwaa_dag_bucket_name" {
  value = aws_s3_bucket.mwaa_dag_bucket.bucket
}

output "mwaa_dag_bucket_arn" {
  value = aws_s3_bucket.mwaa_dag_bucket.arn
}


output "lambda_code_bucket" {
  value = aws_s3_bucket.lambda_code_bucket.id
}

output "processing_code_bucket" {
  value = aws_s3_bucket.processing_code_bucket.bucket
}
*/