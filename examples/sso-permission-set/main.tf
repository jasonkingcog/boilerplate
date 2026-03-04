# Grants an IAM Identity Center group read-only S3 access across a set of accounts
# via the "s3-reader" customer-managed policy.
#
# Pre-requisite: deploy the s3-reader example (../../examples/s3-reader) in each
# account listed in account_ids so the "s3-reader" policy exists before SSO
# assignments are created.
module "s3_reader_permission_set" {
  source = "../../modules/sso-permission-set"

  name        = "S3Reader"
  description = "Grants read-only access to S3 via the s3-reader managed policy."

  group_name = "s3-readers"

  # Must match the policy name deployed in each target account.
  # See the s3-reader example output "customer_managed_policy_arns".
  policy_name = "s3-reader"
  policy_path = "/"

  account_ids = [
    "111122223333",
    "444455556666",
  ]

  session_duration = "PT1H"

  tags = {
    Team        = "platform"
    Environment = "prod"
  }
}

output "permission_set_arn" {
  description = "ARN of the S3Reader permission set."
  value       = module.s3_reader_permission_set.permission_set_arn
}

output "assigned_account_ids" {
  description = "Accounts the permission set was assigned to."
  value       = module.s3_reader_permission_set.assigned_account_ids
}
