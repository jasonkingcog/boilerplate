variable "permission_sets" {
  description = <<-EOT
    Permission sets to create in IAM Identity Center. Key = permission set name.
    Each set supports three policy types:
      - aws_managed_policy_arns:  ARNs of AWS-managed policies (always available in all accounts)
      - customer_managed_policies: Policies referenced by name/path (must exist in each target account)
      - inline_policy_file:        Path to a JSON file embedded directly in the permission set
  EOT
  type = map(object({
    description             = string
    session_duration        = string
    aws_managed_policy_arns = list(string)
    customer_managed_policies = list(object({
      name = string
      path = string
    }))
    inline_policy_file = optional(string)
  }))
  default = {}
}

variable "assignments" {
  description = <<-EOT
    List of group-to-account assignments. Each entry grants a SCIM-synced group
    access to one AWS account via the named permission set.
    A group can appear multiple times to grant access to multiple accounts.
  EOT
  type = list(object({
    group_name          = string
    account_id          = string
    permission_set_name = string
  }))
  default = []
}

variable "region" {
  description = "AWS region where IAM Identity Center is deployed."
  type        = string
  default     = "eu-west-2"
}

variable "tags" {
  description = "Tags applied to all permission sets."
  type        = map(string)
  default     = {}
}
