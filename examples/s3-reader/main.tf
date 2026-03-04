# Deploy this in each target account that should have the s3-reader policy available.
# The sso-permission-set example (../../examples/sso-permission-set) references this
# policy by name to grant SSO group access across accounts.
module "s3_reader_role" {
  source = "../../modules/iam-role"

  name              = "s3-reader"
  trust_policy_file = "${path.module}/trust_policy.json"
  description       = "Allows EC2 instances to read from S3."

  # Customer-managed policy — created in this account and attached to the role
  customer_managed_policies = {
    "s3-reader" = "${path.module}/permissions_policy.json"
  }

  # AWS-managed policy — attached by ARN (must already exist)
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  # Inline policy — embedded directly in the role
  inline_policies = {
    "cloudwatch-logs" = "${path.module}/cloudwatch_inline_policy.json"
  }

  tags = {
    Team        = "platform"
    Environment = "prod"
  }
}

output "role_arn" {
  description = "ARN of the IAM role."
  value       = module.s3_reader_role.role_arn
}

output "customer_managed_policy_arns" {
  description = "ARNs of the customer-managed policies created by this module."
  value       = module.s3_reader_role.customer_managed_policy_arns
}
