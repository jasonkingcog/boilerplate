variable "name" {
  description = "Name for the IAM role and attached customer-managed policy."
  type        = string
}

variable "permissions_policy_file" {
  description = "Path to a JSON file containing the IAM permissions policy document."
  type        = string
}

variable "trust_policy_file" {
  description = "Path to a JSON file containing the IAM trust policy (assume-role) document."
  type        = string
}

variable "description" {
  description = "Description applied to both the IAM role and the managed policy."
  type        = string
  default     = ""
}

variable "path" {
  description = "IAM path under which the role and policy are created."
  type        = string
  default     = "/"
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600–43200)."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
