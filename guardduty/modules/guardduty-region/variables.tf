variable "security_account_id" {
  description = "AWS account ID of the Security/Audit account (delegated admin)."
  type        = string
}

variable "log_archive_account_id" {
  description = "AWS account ID of the Log Archive account where findings buckets are created."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
