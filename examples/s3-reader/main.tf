# Deploy this in each target account that should have the s3-reader policy available.
# The sso-permission-set example (../../examples/sso-permission-set) references this
# policy by name to grant SSO group access across accounts.
module "s3_reader_role" {
  source = "../../modules/iam-role"

  name                    = "s3-reader"
  permissions_policy_file = "${path.module}/permissions_policy.json"
  trust_policy_file       = "${path.module}/trust_policy.json"

  description = "Allows EC2 instances to read from S3."
  tags = {
    Team        = "platform"
    Environment = "prod"
  }
}

output "role_arn" {
  description = "ARN of the IAM role."
  value       = module.s3_reader_role.role_arn
}

output "policy_name" {
  description = "Name of the customer-managed policy. Use this as policy_name in the sso-permission-set module."
  value       = module.s3_reader_role.role_name
}
