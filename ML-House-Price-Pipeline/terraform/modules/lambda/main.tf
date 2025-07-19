resource "aws_lambda_function" "trigger_inference_lambda" {
  function_name    = "${var.project_name}-${var.environment}-trigger-inference"
  runtime          = var.lambda_runtime
  handler          = "trigger_inference.handler"
  role             = var.lambda_role_arn
  s3_bucket        = var.s3_buckets.lambdas
  s3_key           = "trigger_inference.zip"
  #--filename         = "../lambdas/trigger_inference.zip"
  #--source_code_hash = filebase64sha256("../lambdas/trigger_inference.zip")
}

resource "aws_lambda_function" "log_feedback_lambda" {
  function_name     = "${var.project_name}-${var.environment}-log-feedback"
  runtime           = var.lambda_runtime
  handler           = "log_feedback.handler"
  role              = var.lambda_role_arn
  s3_bucket         = var.s3_buckets.lambdas
  s3_key            = "log_feedback.zip"
  #--filename         = "../lambdas/log_feedback.zip"
  #--source_code_hash = filebase64sha256("../lambdas/log_feedback.zip")
  environment {
    variables = {
      PREDICTION_TABLE_NAME = var.prediction_table_name
    }
  }
}


resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${var.project_name}-${var.environment}-lambda-s3-access"
  role = var.lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.s3_buckets.lambdas}",    # lambda source code (trigger_inference, log_feedback)
        "arn:aws:s3:::${var.s3_buckets.lambdas}/*"
      ]
    }]
  })
}

/*
resource "aws_lambda_function" "generate_actuals_lambda" {
  function_name    = "${var.project_name}-${var.environment}-generate-actuals"
  runtime          = var.lambda_runtime
  #filename         = "lambdas/generate_actuals.zip"
  #source_code_hash = filebase64sha256("lambdas/generate_actuals.zip")
  handler          = "generate_actuals.handler"
  role             = var.lambda_role_arn
  s3_bucket        = var.s3_buckets.lambdas
  s3_key           = "lambdas/generate_actuals.zip"
}
*/