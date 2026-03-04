variable "name" {
  description = "Name for the IAM role."
  type        = string
}

variable "trust_policy_file" {
  description = "Path to a JSON file containing the IAM trust policy (assume-role) document."
  type        = string
}

variable "customer_managed_policies" {
  description = "Customer-managed policies to create and attach. Key = policy name, value = path to JSON policy file."
  type        = map(string)
  default     = {}
}

variable "aws_managed_policy_arns" {
  description = "ARNs of AWS-managed or pre-existing customer-managed policies to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Inline policies to embed directly in the role. Key = policy name, value = path to JSON policy file."
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Description applied to the IAM role and any created customer-managed policies."
  type        = string
  default     = ""
}

variable "path" {
  description = "IAM path under which the role and customer-managed policies are created."
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
