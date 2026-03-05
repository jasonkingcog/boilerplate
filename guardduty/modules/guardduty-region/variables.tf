variable "security_account_id" {
  description = "AWS account ID of the Security/Audit account (delegated admin)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
