variable "security_account_id" {
  description = "AWS account ID of the Security/Audit account to designate as GuardDuty delegated admin."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "Must be a 12-digit AWS account ID."
  }
}

variable "management_account_role_arn" {
  description = <<-EOT
    ARN of the IAM role to assume in the management account.
    The role must allow: guardduty:EnableOrganizationAdminAccount,
    organizations:EnableAWSServiceAccess, organizations:RegisterDelegatedAdministrator.
    In a Control Tower environment this is typically AWSControlTowerExecution.
  EOT
  type        = string
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

variable "sentinel_aws_account_id" {
  description = <<-EOT
    AWS account ID used by Microsoft Sentinel to assume the reader role.
    Find this in the Sentinel Amazon Web Services S3 connector setup page in the Azure portal.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.sentinel_aws_account_id))
    error_message = "Must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Tags applied to all GuardDuty resources."
  type        = map(string)
  default     = {}
}
