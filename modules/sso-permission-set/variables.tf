variable "name" {
  description = "Name of the permission set."
  type        = string
}

variable "group_name" {
  description = "Display name of the IAM Identity Center group (synced via SCIM)."
  type        = string
}

variable "policy_name" {
  description = "Name of the customer-managed IAM policy to attach to the permission set. The policy must exist in every target account under the same name and path."
  type        = string
}

variable "policy_path" {
  description = "IAM path of the customer-managed policy."
  type        = string
  default     = "/"
}

variable "account_ids" {
  description = "List of AWS account IDs to assign this permission set to."
  type        = list(string)
}

variable "description" {
  description = "Description of the permission set."
  type        = string
  default     = ""
}

variable "session_duration" {
  description = "Maximum session duration in ISO 8601 format (e.g. PT1H, PT8H). Max PT12H."
  type        = string
  default     = "PT1H"

  validation {
    condition     = can(regex("^PT([0-9]+H)?([0-9]+M)?$", var.session_duration))
    error_message = "session_duration must be a valid ISO 8601 duration (e.g. PT1H, PT30M, PT1H30M)."
  }
}

variable "tags" {
  description = "Tags to apply to the permission set."
  type        = map(string)
  default     = {}
}
