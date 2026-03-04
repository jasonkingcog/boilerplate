output "role_arn" {
  description = "ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "customer_managed_policy_arns" {
  description = "ARNs of the created customer-managed IAM policies, keyed by policy name."
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}
