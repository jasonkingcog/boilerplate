output "instance_id" {
  description = "VSE EC2 instance ID."
  value       = module.zscaler_vse.instance_id
}

output "mgmt_private_ip" {
  description = "Management interface private IP (eth0)."
  value       = module.zscaler_vse.private_ip
}

output "service_private_ip" {
  description = "Service interface private IP (eth1)."
  value       = module.zscaler_vse.secondary_private_ip
}

output "security_group_id" {
  description = "Management security group ID."
  value       = module.zscaler_vse.security_group_id
}
