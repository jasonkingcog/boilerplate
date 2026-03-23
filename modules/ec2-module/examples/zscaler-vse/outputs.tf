output "instance_id" {
  description = "Cloud Connector EC2 instance ID."
  value       = module.zscaler_cc.instance_id
}

output "mgmt_private_ip" {
  description = "Management interface private IP (eth0). Registers with the Zscaler cloud on this IP."
  value       = module.zscaler_cc.private_ip
}

output "service_private_ip" {
  description = "Service interface private IP (eth1). GWLB sends GENEVE traffic to this IP when using IP-type target group registration."
  value       = module.zscaler_cc.secondary_private_ip
}

output "mgmt_security_group_id" {
  description = "Management interface security group ID (auto-created by ec2-module)."
  value       = module.zscaler_cc.security_group_id
}

output "service_security_group_id" {
  description = "Service interface security group ID."
  value       = aws_security_group.service.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the Cloud Connector instance profile."
  value       = module.zscaler_cc.iam_role_arn
}

################################################################################
# Primary Region - Zscaler Subnet Outputs
################################################################################

output "zscaler_subnet_ids" {
  description = "Map of AZ to Zscaler appliance subnet ID (empty if zscaler_subnet_cidrs not set)"
  value       = module.hub_vpc.zscaler_subnet_ids
}

output "zscaler_subnet_ids_list" {
  description = "List of Zscaler appliance subnet IDs (empty if zscaler_subnet_cidrs not set)"
  value       = module.hub_vpc.zscaler_subnet_ids_list
}

output "zscaler_route_table_ids" {
  description = "Map of AZ to Zscaler appliance subnet route table ID (empty if zscaler_subnet_cidrs not set)"
  value       = module.hub_vpc.zscaler_route_table_ids
}
