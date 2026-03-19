variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "zscaler-vse"
}

variable "ami_id" {
  description = "Zscaler VSE AMI ID from the AWS Marketplace (region-specific)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Zscaler recommends c6i.large or larger."
  type        = string
  default     = "c6i.large"
}

variable "key_name" {
  description = "EC2 key pair name for emergency SSH access."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC to deploy the VSE into."
  type        = string
}

variable "mgmt_subnet_id" {
  description = "Subnet for the management interface (eth0)."
  type        = string
}

variable "service_subnet_id" {
  description = "Subnet for the service/data-plane interface (eth1)."
  type        = string
}

variable "mgmt_cidr" {
  description = "CIDR allowed to SSH into the VSE management interface."
  type        = string
}

variable "client_cidr" {
  description = "CIDR of internal clients that will send proxy traffic to the VSE."
  type        = string
}

# ─── Zscaler provisioning ─────────────────────────────────────────────────────

variable "provision_key" {
  description = "Zscaler provisioning key obtained from the ZIA Admin Portal."
  type        = string
  sensitive   = true
}

variable "cloud_name" {
  description = "Zscaler cloud name (e.g. zscaler.net, zscloud.net)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
