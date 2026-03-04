output "permission_set_arns" {
  description = "ARNs of all created permission sets, keyed by name."
  value       = { for k, v in aws_ssoadmin_permission_set.this : k => v.arn }
}

output "group_ids" {
  description = "Identity store group IDs for all referenced SCIM groups, keyed by display name."
  value       = { for k, v in data.aws_identitystore_group.this : k => v.group_id }
}
