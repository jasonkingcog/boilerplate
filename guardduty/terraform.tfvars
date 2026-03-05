# Account ID of your Control Tower Security/Audit account.
# Find this in AWS Organizations or the Control Tower console.
security_account_id = "REPLACE_WITH_SECURITY_ACCOUNT_ID"

# Role to assume in the Security/Audit account.
# AWSControlTowerExecution is deployed by Control Tower in all member accounts.
security_account_role_arn = "arn:aws:iam::REPLACE_WITH_SECURITY_ACCOUNT_ID:role/AWSControlTowerExecution"

# Account ID of the Control Tower Log Archive account.
# Find this in AWS Organizations or the Control Tower console.
log_archive_account_id = "[]"

# Role to assume in the Log Archive account.
# AWSControlTowerExecution is deployed by Control Tower in all member accounts.
log_archive_account_role_arn = "arn:aws:iam::[]]:role/AWSControlTowerExecution"

# Microsoft Sentinel workspace ID (GUID).
# Find this in the Azure portal under Sentinel → Settings → Workspace settings.
sentinel_workspace_id = "REPLACE_WITH_SENTINEL_WORKSPACE_ID"

tags = {
  ManagedBy = "terraform"
  Team      = "security"
}
