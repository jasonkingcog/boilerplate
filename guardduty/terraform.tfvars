# Account ID of your Control Tower Security/Audit account.
# Find this in AWS Organizations or the Control Tower console.
security_account_id = "REPLACE_WITH_SECURITY_ACCOUNT_ID"

# Role to assume in the management account.
# AWSControlTowerExecution is deployed by Control Tower in the management account.
management_account_role_arn = "arn:aws:iam::REPLACE_WITH_MANAGEMENT_ACCOUNT_ID:role/AWSControlTowerExecution"

# Role to assume in the Security/Audit account.
# AWSControlTowerExecution is deployed by Control Tower in all member accounts.
security_account_role_arn = "arn:aws:iam::REPLACE_WITH_SECURITY_ACCOUNT_ID:role/AWSControlTowerExecution"

# AWS account ID used by Microsoft Sentinel to assume the reader role.
# Find this in Sentinel → Data Connectors → Amazon Web Services → Open connector page.
sentinel_aws_account_id = "REPLACE_WITH_SENTINEL_AWS_ACCOUNT_ID"

tags = {
  ManagedBy = "terraform"
  Team      = "security"
}
