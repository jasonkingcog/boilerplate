terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ── To add a new region ────────────────────────────────────────────────────────
# 1. Add three provider blocks below (management_<region> with no assume_role, security_<region>, log_archive_<region>)
# 2. Add a module call in main.tf referencing those providers
# 3. Add an output block in outputs.tf

# ── eu-west-2 ──────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "management_eu_west_2"
  region = "eu-west-2"
  # No assume_role — pipeline runs with management account credentials directly
}

provider "aws" {
  alias  = "security_eu_west_2"
  region = "eu-west-2"
  assume_role { role_arn = var.security_account_role_arn }
}

provider "aws" {
  alias  = "log_archive_eu_west_2"
  region = "eu-west-2"
  assume_role { role_arn = var.log_archive_account_role_arn }
}

# ── eu-west-1 ──────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "management_eu_west_1"
  region = "eu-west-1"
  # No assume_role — pipeline runs with management account credentials directly
}

provider "aws" {
  alias  = "security_eu_west_1"
  region = "eu-west-1"
  assume_role { role_arn = var.security_account_role_arn }
}

provider "aws" {
  alias  = "log_archive_eu_west_1"
  region = "eu-west-1"
  assume_role { role_arn = var.log_archive_account_role_arn }
}
