# modules/sagemaker/main.tf
resource "aws_iam_policy" "sagemaker_inline_policy" {
  name = "${var.project_name}-${var.environment}-sagemaker-inline-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
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
          "arn:aws:s3:::${var.s3_buckets.feedback_data}",
          "arn:aws:s3:::${var.s3_buckets.feedback_data}/*"
        ]
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
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
    ]
  })
}


/* ==============================================================
resource "aws_sagemaker_processing_job" "data_prep" {
  name = "${var.project_name}-${var.environment}-data-prep"
  app_specification {
    image_uri = "your-preprocessing-image-uri"
  }

  role_arn = var.sagemaker_execution_role_arn

  processing_inputs {
    input_name              = "input-data"
    s3_input {
      s3_data_type     = "S3Prefix"
      s3_uri             = "s3://${var.s3_buckets.raw_data}/train.csv"
      s3_data_distribution_type = "FullyReplicated"
      s3_input_mode     = "File"
      s3_compression_type = "None"
    }
  }

  processing_output_config {
    outputs {
      output_name = "processed-data"
      s3_output {
        s3_uri = "s3://${var.s3_buckets.processed_data}"
        s3_upload_mode = "EndOfJob"
      }
    }
  }

  processing_resources {
    cluster_config {
      instance_count    = 1
      instance_type     = "ml.t3.medium"
      volume_size_in_gb = 30
    }
  }

  stopping_condition {
    max_runtime_in_seconds = 3600
  }
}
*/

/*
resource "aws_iam_role_policy_attachment" "sagemaker_custom" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = aws_iam_policy.sagemaker_inline_policy.arn
}
*/

