provider "aws" {
  region = var.region
}

module "s3" {
  source = "./modules/s3"
  project_name = var.project_name
  environment = var.environment
}

module "iam" {
  source = "./modules/iam"
  project_name    = var.project_name
  environment     = var.environment
  #source_bucket_name  = module.s3.mwaa_dag_bucket_name
  s3_buckets = {
    raw_data        = module.s3.raw_data_bucket
    processed_data  = module.s3.processed_data_bucket
    feedback_data   = module.s3.feedback_data_bucket
    code_bucket       = module.s3.code_bucket
    /*==
    lambdas         = module.s3.lambda_code_bucket
    dags            = module.s3.mwaa_dag_bucket_name
    */
  }
}

module "lambda" {
  source = "./modules/lambda"
  project_name = var.project_name
  environment = var.environment
  lambda_role_arn = module.iam.lambda_role_arn
  lambda_role_name = module.iam.lambda_role_name
  s3_buckets = {
    raw_data      = module.s3.raw_data_bucket
    processed_data = module.s3.processed_data_bucket
    feedback_data = module.s3.feedback_data_bucket
    code_bucket       = module.s3.code_bucket
    #lambdas       = module.s3.lambda_code_bucket      # defined in modules/s3/main.tf
  }
  prediction_table_name = module.dynamodb.prediction_logs_table
  lambda_runtime = var.lambda_runtime
}

module "dynamodb" {
  source = "./modules/dynamodb"
  project_name = var.project_name
  environment = var.environment
}

module "eventbridge" {
  source = "./modules/eventbridge"
  project_name = var.project_name
  environment = var.environment
  lambda_arn = module.lambda.trigger_inference_lambda_arn
}


module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
}

module "mwaa" {
  source = "./modules/mwaa"

  project_name        = var.project_name
  environment         = var.environment
  airflow_role_arn    = module.iam.mwaa_role_arn
  dag_s3_path         = "dags/"
  source_bucket_arn   = module.s3.mwaa_dag_bucket_arn   # from modules/s3/output.tf
  s3_buckets = {
    raw_data          = module.s3.raw_data_bucket
    processed_data    = module.s3.processed_data_bucket
    feedback_data     = module.s3.feedback_data_bucket
    code_bucket       = module.s3.code_bucket
    #code_bucket       = module.s3.processing_code_bucket        # defined in modules/s3/main.tf
  }

  # VPC Networking
  security_group_id   = module.vpc.security_group_id    # from modules/vpc/outputs.tf
  subnet_ids          = module.vpc.private_subnet_ids   # MWAA must use private subnet, from modules/vpc/outputs.tf
}

module "sagemaker" {
  source = "./modules/sagemaker"

  project_name    = var.project_name
  environment     = var.environment
  s3_buckets = {
    raw_data       = module.s3.raw_data_bucket
    processed_data = module.s3.processed_data_bucket
    feedback_data  = module.s3.feedback_data_bucket
  }
  sagemaker_execution_role_arn = module.iam.sagemaker_execution_role_arn
}