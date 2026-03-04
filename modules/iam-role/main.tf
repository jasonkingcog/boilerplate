resource "aws_iam_role" "this" {
  name                 = var.name
  path                 = var.path
  description          = var.description
  assume_role_policy   = file(var.trust_policy_file)
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

# Customer-managed policies — created and attached
resource "aws_iam_policy" "this" {
  for_each    = var.customer_managed_policies
  name        = each.key
  path        = var.path
  description = var.description
  policy      = file(each.value)
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "customer_managed" {
  for_each   = var.customer_managed_policies
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[each.key].arn
}

# AWS-managed or pre-existing policies — attached by ARN
resource "aws_iam_role_policy_attachment" "aws_managed" {
  for_each   = toset(var.aws_managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Inline policies — embedded directly in the role
resource "aws_iam_role_policy" "this" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.this.id
  policy   = file(each.value)
}
