resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = "${var.project_name}-${var.environment}-raw-data"
}

resource "aws_s3_bucket" "processed_data_bucket" {
  bucket = "${var.project_name}-${var.environment}-processed-data"
}

resource "aws_s3_bucket" "feedback_data_bucket" {
  bucket = "${var.project_name}-${var.environment}-feedback-data"
}

resource "aws_s3_bucket" "model_monitor_output_bucket" {
  bucket = "${var.project_name}-${var.environment}-model-monitor-output"
}

resource "aws_s3_bucket" "code_bucket" {
  bucket = "${var.project_name}-${var.environment}-code"
}

/* ==========
resource "aws_s3_bucket" "mwaa_dag_bucket" {
  bucket = "${var.project_name}-${var.environment}-mwaa-bucket"

  tags = {
    Name = "${var.project_name}-${var.environment}-mwaa-dags"
  }
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "${var.project_name}-${var.environment}-lambda-code"
}

resource "aws_s3_bucket" "processing_code_bucket" {
  bucket = "${var.project_name}-${var.environment}-processing-code"
}
*/