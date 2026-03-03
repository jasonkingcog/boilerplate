resource "aws_iam_role" "this" {
  name                 = var.name
  path                 = var.path
  description          = var.description
  assume_role_policy   = file(var.trust_policy_file)
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_policy" "this" {
  name        = var.name
  path        = var.path
  description = var.description
  policy      = file(var.permissions_policy_file)
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
