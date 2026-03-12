# Grants the Cyber team read-only access across all accounts, with S3 access
# restricted to their designated accounts only.
module "stw_readonly_cyber" {
  source = "../../modules/sso-permission-set"

  name        = "stw-readonly-cyber"
  description = "Allows Cyber Read Only to All Accounts but denies access to S3 outside of cyber accounts"

  group_name = "stw-readonly-cyber"

  # Broad read-only access across all AWS services.
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  # Deny S3 access when operating in any account that is not a designated cyber account.
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyS3OutsideCyberAccounts"
        Effect = "Deny"
        Action = "s3:*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = [
              "111122223333",
              "444455556666",
            ]
          }
        }
      }
    ]
  })

  # List all accounts this permission set should be assigned to.
  account_ids = [
    "111122223333",
    "444455556666",
  ]

  session_duration = "PT1H"

  tags = {
    Team        = "cyber"
    Environment = "prod"
  }
}

output "permission_set_arn" {
  description = "ARN of the stw-readonly-cyber permission set."
  value       = module.stw_readonly_cyber.permission_set_arn
}

output "assigned_account_ids" {
  description = "Accounts the permission set was assigned to."
  value       = module.stw_readonly_cyber.assigned_account_ids
}
