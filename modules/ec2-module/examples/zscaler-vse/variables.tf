variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "zscaler-cc"
}

variable "ami_id" {
  description = "Zscaler Cloud Connector AMI ID from the AWS Marketplace (region-specific)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Refer to the Zscaler sizing guide — m5.large is the minimum."
  type        = string
  default     = "m5.large"
}

variable "key_name" {
  description = "EC2 key pair name for emergency SSH access. Leave null to disable."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC to deploy Cloud Connector into."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Used to scope GWLB GENEVE and health check ingress rules."
  type        = string
}

variable "zscaler_subnet_id" {
  description = "Subnet for both the management (eth0) and service (eth1) interfaces. Both NICs share the same dedicated Zscaler subnet."
  type        = string
}

variable "mgmt_cidr" {
  description = "CIDR allowed to SSH into the Cloud Connector management interface. Leave empty to disable SSH ingress."
  type        = string
  default     = ""
}

# ─── Zscaler provisioning ─────────────────────────────────────────────────────

variable "prov_url" {
  description = "Cloud Connector provisioning URL from the Zscaler Cloud & Branch Connector Admin Portal (Administration → Cloud Connector Groups → Provisioning URL)."
  type        = string
}

variable "secret_name" {
  description = "Name of the AWS Secrets Manager secret containing Cloud Connector API credentials ({api_key, username, password}). Must exist before terraform apply."
  type        = string
}

variable "http_probe_port" {
  description = "Port the GWLB health check probes on the Cloud Connector instance. Must match the port configured in the GWLB target group."
  type        = number
  default     = 50000
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

################################################################################
# Zscaler Cloud Connector Configuration
################################################################################

variable "create_zscaler_cloud_connector" {
  description = "Deploy Zscaler Cloud Connector instances (one per AZ) behind a Gateway Load Balancer."
  type        = bool
  default     = false
}

variable "zscaler_cc_ami_id" {
  description = "Zscaler Cloud Connector AMI ID. Accept the Marketplace subscription before use."
  type        = string
  default     = ""
}

variable "zscaler_cc_instance_type" {
  description = "EC2 instance type for Cloud Connector. Refer to Zscaler sizing guide."
  type        = string
  default     = "m5.large"
}

variable "zscaler_cc_key_name" {
  description = "EC2 key pair name for Cloud Connector SSH access. Leave null to disable."
  type        = string
  default     = null
}

variable "zscaler_cc_mgmt_cidr" {
  description = "CIDR allowed to SSH to Cloud Connector management interfaces."
  type        = string
  default     = ""
}

variable "zscaler_cc_prov_url" {
  description = "Zscaler Cloud Connector provisioning URL generated from the Zscaler Cloud & Branch Connector admin portal."
  type        = string
  default     = ""
}

variable "zscaler_cc_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing Zscaler API credentials (api_key, username, password). Cloud Connector fetches these at boot using its IAM role."
  type        = string
  default     = ""
}

variable "zscaler_cc_http_probe_port" {
  description = "Port Cloud Connector listens on for GWLB health checks. Must match the value configured in the Zscaler admin portal."
  type        = number
  default     = 50000
}

variable "zscaler_cc_instances_per_az" {
  description = "Number of Cloud Connector instances to deploy per AZ. All instances in an AZ share the same Zscaler subnet and are registered as individual targets in the GWLB target group. Increase beyond 1 for higher throughput capacity within an AZ."
  type        = number
  default     = 1

  validation {
    condition     = var.zscaler_cc_instances_per_az >= 1 && var.zscaler_cc_instances_per_az <= 5
    error_message = "Between 1 and 5 Cloud Connector instances per AZ are supported."
  }
}

variable "zscaler_cc_stickiness_enabled" {
  description = "Enable GWLB target group stickiness (source_ip_dest_ip_proto). When enabled, flows from the same source IP, destination IP, and protocol are always forwarded to the same Cloud Connector. Leave false (5-tuple) for even distribution across the pool."
  type        = bool
  default     = false
}

variable "zscaler_cc_cross_zone_lb_enabled" {
  description = "Enable cross-zone load balancing on the GWLB. When true, the GWLB distributes traffic evenly across all Cloud Connector instances regardless of AZ. When false (default), traffic stays within the originating AZ."
  type        = bool
  default     = false
}

################################################################################
# Endpoint Policy Configuration
################################################################################

variable "aws_organization_id" {
  description = "AWS Organizations ID (e.g. o-xxxxxxxxxx). When provided and no explicit endpoint policy is given, a default policy restricting endpoint access to organisation principals is generated automatically."
  type        = string
  default     = ""
}

variable "interface_endpoint_policy" {
  description = "IAM policy document (JSON) to attach to all interface VPC endpoints. When null and aws_organization_id is set, a default org-restricted policy is applied. When null and no org ID is set, the AWS-managed default (allow all) applies."
  type        = string
  default     = null
}

variable "gateway_endpoint_policy" {
  description = "IAM policy document (JSON) to attach to all gateway VPC endpoints (S3, DynamoDB). When null and aws_organization_id is set, a default org-restricted policy is applied. When null and no org ID is set, the AWS-managed default (allow all) applies."
  type        = string
  default     = null
}

################################################################################
# Zscaler Cloud Connector Outputs
################################################################################

output "zscaler_cc_gwlb_arn" {
  description = "ARN of the Gateway Load Balancer fronting Cloud Connector (null if not enabled)"
  value       = one(aws_lb.zscaler_cc[*].arn)
}

output "zscaler_cc_gwlb_endpoint_service_name" {
  description = "GWLB endpoint service name — share this with spoke VPCs to create GatewayLoadBalancer endpoints (null if not enabled)"
  value       = one(aws_vpc_endpoint_service.zscaler_cc[*].service_name)
}

output "zscaler_cc_gwlb_endpoint_ids" {
  description = "Map of AZ to GWLB endpoint ID in the hub VPC — use these as next-hops in spoke route tables (empty if not enabled)"
  value       = { for az, ep in aws_vpc_endpoint.zscaler_cc : az => ep.id }
}

output "zscaler_cc_instance_ids" {
  description = "Map of '<az>-<n>' to Cloud Connector instance ID (empty if not enabled)"
  value       = { for key, m in module.zscaler_cc : key => m.instance_id }
}

output "zscaler_cc_mgmt_ips" {
  description = "Map of '<az>-<n>' to Cloud Connector management interface (eth0) private IP (empty if not enabled)"
  value       = { for key, m in module.zscaler_cc : key => m.private_ip }
}
