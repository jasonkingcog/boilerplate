# SSO instance — one per AWS organization, provisioned by Control Tower.
data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# ── Permission Sets ────────────────────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "this" {
  for_each         = var.permission_sets
  name             = each.key
  instance_arn     = local.instance_arn
  description      = each.value.description
  session_duration = each.value.session_duration
  tags             = var.tags
}

# AWS-managed policies — attached by ARN, always available in every account.
resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = {
    for item in flatten([
      for ps_name, ps in var.permission_sets : [
        for arn in ps.aws_managed_policy_arns : {
          key        = "${ps_name}::${arn}"
          ps_name    = ps_name
          policy_arn = arn
        }
      ]
    ]) : item.key => item
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_name].arn
  managed_policy_arn = each.value.policy_arn
}

# Customer-managed policies — referenced by name; must exist in each target account.
resource "aws_ssoadmin_customer_managed_policy_attachment" "this" {
  for_each = {
    for item in flatten([
      for ps_name, ps in var.permission_sets : [
        for policy in ps.customer_managed_policies : {
          key     = "${ps_name}::${policy.name}::${policy.path}"
          ps_name = ps_name
          name    = policy.name
          path    = policy.path
        }
      ]
    ]) : item.key => item
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_name].arn

  customer_managed_policy_reference {
    name = each.value.name
    path = each.value.path
  }
}

# Inline policies — embedded directly in the permission set.
resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = {
    for k, v in var.permission_sets : k => v.inline_policy
    if v.inline_policy != null
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value
}

# ── Groups ─────────────────────────────────────────────────────────────────────

# Look up each unique SCIM-synced group referenced across all assignments.
data "aws_identitystore_group" "this" {
  for_each          = toset([for a in var.assignments : a.group_name])
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

# ── Account Assignments ────────────────────────────────────────────────────────

# Grants each group access to an account via the specified permission set.
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = {
    for a in var.assignments :
    "${a.group_name}::${a.account_id}::${a.permission_set_name}" => a
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set_name].arn

  principal_id   = data.aws_identitystore_group.this[each.value.group_name].group_id
  principal_type = "GROUP"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}
