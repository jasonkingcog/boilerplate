# ─── Core ────────────────────────────────────────────────────────────────────

variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch. For Marketplace AMIs, ensure you have accepted the subscription in the AWS Console first."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "c6i.large"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Leave empty to launch without SSH key access."
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "VPC in which to create resources."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the primary network interface (eth0 / management)."
  type        = string
}

variable "associate_public_ip" {
  description = "Associate a public IP on the primary interface. Disabled when secondary_subnet_id is set (use an EIP instead)."
  type        = bool
  default     = false
}

# Secondary interface — used for appliances like Zscaler ZIA VSE that need a
# separate data-plane / service interface.
variable "secondary_subnet_id" {
  description = "Subnet for a second network interface (eth1 / service). Leave null for single-NIC instances."
  type        = string
  default     = null
}

variable "secondary_security_group_ids" {
  description = "Security group IDs for the secondary interface."
  type        = list(string)
  default     = []
}

# ─── Security Groups ──────────────────────────────────────────────────────────

variable "security_group_ids" {
  description = "List of existing security group IDs to attach to the primary interface. A dedicated SG is always created; these are added on top."
  type        = list(string)
  default     = []
}

variable "ingress_rules" {
  description = "Ingress rules for the module-managed security group."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "Egress rules for the module-managed security group. Defaults to allow-all."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# ─── IAM ──────────────────────────────────────────────────────────────────────

variable "iam_instance_profile" {
  description = "Name of an existing IAM instance profile. A minimal SSM profile is created when this is null and create_ssm_role is true."
  type        = string
  default     = null
}

variable "create_ssm_role" {
  description = "Create an IAM role/profile that allows SSM Session Manager access when no iam_instance_profile is provided."
  type        = bool
  default     = true
}

# ─── Storage ──────────────────────────────────────────────────────────────────

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Encrypt the root EBS volume."
  type        = bool
  default     = true
}

variable "root_volume_kms_key_id" {
  description = "KMS key ARN for root volume encryption. Uses the default AWS-managed key when empty."
  type        = string
  default     = null
}

variable "ebs_optimized" {
  description = "Launch as EBS-optimized. Most modern instance types support this at no extra cost."
  type        = bool
  default     = true
}

# ─── User Data ────────────────────────────────────────────────────────────────

variable "user_data" {
  description = "Raw user data string (cloud-init / shell script). Takes precedence over user_data_templatefile."
  type        = string
  default     = null
  sensitive   = true
}

variable "user_data_templatefile" {
  description = "Path to a templatefile for user data. Rendered with user_data_vars."
  type        = string
  default     = null
}

variable "user_data_vars" {
  description = "Variables passed to user_data_templatefile when rendering."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ─── Monitoring & Misc ────────────────────────────────────────────────────────

variable "detailed_monitoring" {
  description = "Enable detailed (1-minute) CloudWatch monitoring."
  type        = bool
  default     = false
}

variable "instance_initiated_shutdown_behavior" {
  description = "Shutdown behavior: 'stop' or 'terminate'."
  type        = string
  default     = "stop"

  validation {
    condition     = contains(["stop", "terminate"], var.instance_initiated_shutdown_behavior)
    error_message = "Must be 'stop' or 'terminate'."
  }
}

variable "disable_api_termination" {
  description = "Enable termination protection."
  type        = bool
  default     = false
}

variable "source_dest_check" {
  description = "Enable source/destination check on the primary interface. Set false for NAT/appliance instances."
  type        = bool
  default     = true
}
