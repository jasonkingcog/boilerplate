# ─────────────────────────────────────────────────────────────────────────────
# Zscaler Cloud Connector — single instance example
#
# Demonstrates how to deploy one Cloud Connector using the ec2-module with the
# same configuration used by the core-network-hub appliances.tf. In production
# the instance is deployed N-per-AZ via for_each and sits behind a Gateway Load
# Balancer (GWLB). This example isolates the instance-level configuration.
#
# Prerequisites
# 1. Accept the Marketplace subscription for the Zscaler Cloud Connector AMI
#    in the AWS Console (one-time, per-account) before running terraform apply.
# 2. Retrieve the current Marketplace AMI ID for your region:
#    aws ec2 describe-images \
#      --owners aws-marketplace \
#      --filters "Name=product-code,Values=<zscaler-cc-product-code>" \
#      --query "sort_by(Images, &CreationDate)[-1].ImageId" \
#      --output text
# 3. Create the Secrets Manager secret before apply — Cloud Connector reads it
#    at boot to authenticate with the Zscaler cloud:
#    aws secretsmanager create-secret \
#      --name "<secret_name>" \
#      --secret-string '{"api_key":"xxx","username":"svc@example.com","password":"xxx"}'
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
# Looked up by name so the IAM policy can scope GetSecretValue to the exact ARN.

data "aws_secretsmanager_secret" "zscaler_cc" {
  name = var.secret_name
}

# ─── Cloud Connector IAM Policy ───────────────────────────────────────────────
# Created here and passed to the ec2-module via additional_policy_arns so the
# auto-created SSM role receives all permissions Cloud Connector needs at boot.

resource "aws_iam_policy" "zscaler_cc" {
  name        = "${var.name}-policy"
  description = "Permissions required by Zscaler Cloud Connector"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ServiceDiscovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      },
      {
        Sid      = "ProvisioningCredentials"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [data.aws_secretsmanager_secret.zscaler_cc.arn]
      },
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Zscaler/CloudConnectors"
          }
        }
      },
    ]
  })

  tags = var.tags
}

# ─── Zscaler Cloud Connector ───────────────────────────────────────────────────

module "zscaler_cc" {
  source = "../../"

  name          = var.name
  ami_id        = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_id    = var.vpc_id
  subnet_id = var.zscaler_subnet_id # eth0 — management

  # eth1 — service/data-plane interface (GWLB sends GENEVE traffic here)
  secondary_subnet_id          = var.zscaler_subnet_id
  secondary_security_group_ids = [aws_security_group.service.id]

  # Cloud Connector forwards traffic — source/dest check must be off on both NICs
  source_dest_check = false

  # Management interface — SSH access only
  ingress_rules = var.mgmt_cidr != "" ? [
    {
      description = "SSH from management CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.mgmt_cidr]
    },
  ] : []

  root_volume_size      = 20
  root_volume_encrypted = true

  # Cloud Connector reads CC_URL, SECRET_NAME, and HTTP_PROBE_PORT from user data
  # at boot to register with the Zscaler cloud and configure the health probe.
  user_data_templatefile = "${path.module}/user_data.tpl"
  user_data_vars = {
    prov_url        = var.prov_url
    secret_name     = var.secret_name
    http_probe_port = var.http_probe_port
  }

  associate_public_ip = false # Egress to internet via NAT Gateway in hub VPC

  # SSM role is created by the module; additional_policy_arns attaches the
  # Cloud Connector-specific permissions on top of AmazonSSMManagedInstanceCore.
  create_ssm_role        = true
  additional_policy_arns = [aws_iam_policy.zscaler_cc.arn]

  tags = var.tags
}

# ─── Service Interface Security Group ─────────────────────────────────────────
# eth1 receives GENEVE-encapsulated traffic from the GWLB (UDP 6081) and
# responds to GWLB health checks on http_probe_port.

resource "aws_security_group" "service" {
  name        = "${var.name}-service-sg"
  description = "Zscaler Cloud Connector service interface - GWLB GENEVE traffic"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-service-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "geneve" {
  security_group_id = aws_security_group.service.id
  description       = "GWLB GENEVE encapsulated traffic"
  from_port         = 6081
  to_port           = 6081
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "health" {
  security_group_id = aws_security_group.service.id
  description       = "GWLB health checks on http_probe_port"
  from_port         = var.http_probe_port
  to_port           = var.http_probe_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "service_all" {
  security_group_id = aws_security_group.service.id
  description       = "Allow all outbound from service interface"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = var.tags
}
