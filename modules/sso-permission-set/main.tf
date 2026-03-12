# Discover the SSO instance - there is only ever one per AWS organization.
data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Look up the SCIM-synced group by display name.
data "aws_identitystore_group" "this" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = var.group_name
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  name             = var.name
  instance_arn     = local.instance_arn
  description      = var.description
  session_duration = var.session_duration
  tags             = var.tags
}

# Inline policy — defined directly in the caller's HCL via jsonencode().
resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  count = var.inline_policy != null ? 1 : 0

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  inline_policy      = var.inline_policy
}

# AWS-managed policy attachments.
resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = toset(var.aws_managed_policy_arns)

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  managed_policy_arn = each.value
}

# One assignment per target account: grants the group access via this permission set.
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = toset(var.account_ids)

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn

  principal_id   = data.aws_identitystore_group.this.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"

  depends_on = [
    aws_ssoadmin_permission_set_inline_policy.this,
    aws_ssoadmin_managed_policy_attachment.this,
  ]
}
