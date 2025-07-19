data "aws_caller_identity" "current" {}   # dynamic account ID

# SageMaker Execution Role
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.project_name}-${var.environment}-sagemaker-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_basic" {
  name = "lambda-basic-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_buckets.raw_data}",
          "arn:aws:s3:::${var.s3_buckets.processed_data}",
          "arn:aws:s3:::${var.s3_buckets.feedback_data}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = "*"
      }
    ]
  })
}

# MWAA Role
resource "aws_iam_role" "mwaa_role" {
  name = "${var.project_name}-${var.environment}-mwaa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "airflow-env.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "mwaa_inline_policy" {
  name = "${var.project_name}-${var.environment}-mwaa-inline-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "airflow:PublishMetrics"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_buckets.dags}",
          "arn:aws:s3:::${var.s3_buckets.dags}/*"
        ]
      },
      /* ===========
      {
        Effect = "Allow",
        Action = [
          "s3:GetBucketPublicAccessBlock"
        ],
        Resource = "arn:aws:s3:::${var.s3_buckets.dags}"
      },
      ============ */
      ### Add S3 access to processing inputs/outputs
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_buckets.raw_data}",
          "arn:aws:s3:::${var.s3_buckets.raw_data}/*",
          "arn:aws:s3:::${var.s3_buckets.processed_data}",
          "arn:aws:s3:::${var.s3_buckets.processed_data}/*",
          "arn:aws:s3:::${var.s3_buckets.code_bucket}",       # store preprocessing.py
          "arn:aws:s3:::${var.s3_buckets.code_bucket}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetAccountPublicAccessBlock"    # global action, not specific to a bucket
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sagemaker:CreateProcessingJob",
          "sagemaker:DescribeProcessingJob",
          "sagemaker:ListProcessingJobs"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-sagemaker-execution-role"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mwaa_custom" {
  role       = aws_iam_role.mwaa_role.name
  policy_arn = aws_iam_policy.mwaa_inline_policy.arn
}

/* ===========
resource "aws_iam_role_policy_attachment" "mwaa_full_access" {
  role       = aws_iam_role.mwaa_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSManagedAirflowServiceRolePolicy"
}

resource "aws_iam_role_policy_attachment" "mwaa_access" {
  role       = aws_iam_role.mwaa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMWAARolePolicy"
}

resource "aws_iam_role_policy_attachment" "mwaa_webserver_access" {
  role       = aws_iam_role.mwaa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAWebServerAccess"
}

*/