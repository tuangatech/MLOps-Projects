resource "aws_dynamodb_table" "prediction_logs" {
  name           = "${var.project_name}-${var.environment}-predictions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "inference_id"

  attribute {
    name = "inference_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}