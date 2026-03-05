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
# 1. Add two provider blocks below (management_<region> and security_<region>)
# 2. Add a module call in main.tf referencing those providers
# 3. Add an output block in outputs.tf

# ── eu-west-2 ──────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "management_eu_west_2"
  region = "eu-west-2"
  assume_role { role_arn = var.management_account_role_arn }
}

provider "aws" {
  alias  = "security_eu_west_2"
  region = "eu-west-2"
  assume_role { role_arn = var.security_account_role_arn }
}

# ── eu-west-1 ──────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "management_eu_west_1"
  region = "eu-west-1"
  assume_role { role_arn = var.management_account_role_arn }
}

provider "aws" {
  alias  = "security_eu_west_1"
  region = "eu-west-1"
  assume_role { role_arn = var.security_account_role_arn }
}
