# ─────────────────────────────────────────────────────────────────────────────
# Zscaler Internet Access — Virtual Service Edge (VSE)
#
# Prerequisites
# 1. Accept the Marketplace subscription for the Zscaler VSE AMI in the AWS
#    Console (one-time, per-account) before running terraform apply.
# 2. Retrieve the current Marketplace AMI ID for your region:
#    aws ec2 describe-images \
#      --owners aws-marketplace \
#      --filters "Name=product-code,Values=<zscaler-product-code>" \
#      --query "sort_by(Images, &CreationDate)[-1].ImageId" \
#      --output text
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Data ─────────────────────────────────────────────────────────────────────

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ─── Zscaler VSE ──────────────────────────────────────────────────────────────

module "zscaler_vse" {
  source = "../../"

  name          = var.name
  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_id    = var.vpc_id
  subnet_id = var.mgmt_subnet_id # eth0 — management

  # eth1 — service/data-plane interface (ZIA VSE uses two NICs)
  secondary_subnet_id          = var.service_subnet_id
  secondary_security_group_ids = [aws_security_group.service.id]

  # Management SG rules
  ingress_rules = [
    {
      description = "SSH from management CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.mgmt_cidr]
    },
    {
      description = "ICMP from VPC"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
    },
  ]

  # Source/dest check must be disabled — VSE forwards traffic
  source_dest_check = false

  # Zscaler recommends c6i/c5 instance families for VSE
  # Root volume: VSE typically ships with a pre-configured disk; 20 GiB is sufficient
  root_volume_size      = 20
  root_volume_encrypted = true

  # Cloud-init / user data for VSE provisioning
  # See Zscaler documentation for the expected format and required variables.
  user_data_templatefile = "${path.module}/user_data.tpl"
  user_data_vars = {
    provision_key = var.provision_key
    cloud_name    = var.cloud_name
  }

  associate_public_ip = false # Use a NAT Gateway or Direct Connect instead

  create_ssm_role = true # Enables SSM Session Manager as a fallback console

  tags = var.tags
}

# ─── Service Interface Security Group ─────────────────────────────────────────
# The service interface handles proxied user traffic; lock it down to your
# internal clients only.

resource "aws_security_group" "service" {
  name        = "${var.name}-service-sg"
  description = "Zscaler VSE service interface"
  vpc_id      = var.vpc_id

  ingress {
    description = "Proxy traffic from clients"
    from_port   = 9400
    to_port     = 9400
    protocol    = "tcp"
    cidr_blocks = [var.client_cidr]
  }

  ingress {
    description = "PAC file / HTTP proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.client_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-service-sg" })
}
