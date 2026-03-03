output "permission_set_arn" {
  description = "ARN of the permission set."
  value       = aws_ssoadmin_permission_set.this.arn
}

output "permission_set_name" {
  description = "Name of the permission set."
  value       = aws_ssoadmin_permission_set.this.name
}

output "group_id" {
  description = "Identity store ID of the resolved group."
  value       = data.aws_identitystore_group.this.group_id
}

output "assigned_account_ids" {
  description = "Account IDs this permission set was assigned to."
  value       = var.account_ids
}
