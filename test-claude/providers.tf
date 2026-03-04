terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# IAM Identity Center is a global service managed from the management account.
# Provide credentials for the management account using one of:
#   a) Environment variables: AWS_PROFILE, AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   b) An assume_role block targeting the management account role
provider "aws" {
  region = var.region
}
