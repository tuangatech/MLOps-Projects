# main.tf - Entry point for Terraform
# This file includes provider configuration and links all modules/resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.region
}

# You can optionally include module calls here if you modularize your config later
# For now, all resources are defined directly in individual .tf files