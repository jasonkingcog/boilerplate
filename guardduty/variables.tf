variable "security_account_id" {
  description = "AWS account ID of the Security/Audit account to designate as GuardDuty delegated admin."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "Must be a 12-digit AWS account ID."
  }
}

variable "security_account_role_arn" {
  description = <<-EOT
    ARN of the IAM role to assume in the Security/Audit account.
    The role must allow: guardduty:*, organizations:DescribeOrganization,
    organizations:ListAccounts, organizations:ListDelegatedAdministrators.
    In a Control Tower environment this is typically AWSControlTowerExecution.
  EOT
  type        = string
}

variable "log_archive_account_id" {
  description = "AWS account ID of the Log Archive account where findings buckets are created."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.log_archive_account_id))
    error_message = "Must be a 12-digit AWS account ID."
  }
}

variable "log_archive_account_role_arn" {
  description = <<-EOT
    ARN of the IAM role to assume in the Log Archive account.
    The role must allow: s3:*, kms:*, sqs:*, iam:*, sts:GetCallerIdentity.
    In a Control Tower environment this is typically AWSControlTowerExecution.
  EOT
  type        = string
}

variable "sentinel_workspace_id" {
  description = <<-EOT
    Microsoft Sentinel workspace ID (GUID).
    Find this in the Azure portal under Sentinel → Settings → Workspace settings.
    Used in the IAM role trust policy RoleSessionName condition.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.sentinel_workspace_id))
    error_message = "Must be a valid GUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
  }
}

variable "tags" {
  description = "Tags applied to all GuardDuty resources."
  type        = map(string)
  default     = {}
}
