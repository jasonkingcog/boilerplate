output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Primary private IP address."
  value       = aws_network_interface.primary.private_ip
}

output "public_ip" {
  description = "Elastic IP address (if associate_public_ip = true)."
  value       = length(aws_eip.primary) > 0 ? aws_eip.primary[0].public_ip : null
}

output "primary_eni_id" {
  description = "Primary network interface ID."
  value       = aws_network_interface.primary.id
}

output "secondary_eni_id" {
  description = "Secondary network interface ID (null when not created)."
  value       = length(aws_network_interface.secondary) > 0 ? aws_network_interface.secondary[0].id : null
}

output "secondary_private_ip" {
  description = "Secondary interface private IP (null when not created)."
  value       = length(aws_network_interface.secondary) > 0 ? aws_network_interface.secondary[0].private_ip : null
}

output "security_group_id" {
  description = "ID of the module-managed security group."
  value       = aws_security_group.this.id
}

output "iam_role_arn" {
  description = "ARN of the SSM IAM role (null when an external profile is used)."
  value       = length(aws_iam_role.ssm) > 0 ? aws_iam_role.ssm[0].arn : null
}
