resource "aws_cloudwatch_event_rule" "inference_schedule" {
  name                = "${var.project_name}-${var.environment}-inference-schedule"
  schedule_expression = "rate(60 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule  = aws_cloudwatch_event_rule.inference_schedule.name
  arn   = var.lambda_arn
}