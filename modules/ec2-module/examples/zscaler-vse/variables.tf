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
