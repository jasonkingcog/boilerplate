################################################################################
# Zscaler Cloud Connector — Horizontal Scaling behind a Gateway Load Balancer
#
# zscaler_cc_instances_per_az controls how many Cloud Connector instances are
# deployed in each AZ. All instances share the same Zscaler subnet for that AZ
# and are registered as individual IP targets in the GWLB target group via their
# forwarding interface (eth0), which distributes traffic across the pool.
#
#   eth0 (device_index=0) — service/forwarding, GWLB targets this IP
#   eth1 (device_index=1) — management (SSH/SSM), attached post-launch
#
# The GWLB uses IP-type target group registration targeting eth0 (private_ip).
# Cloud Connector intercepts traffic transparently — no explicit proxy config
# required on clients. Route tables redirect traffic to the GWLB endpoint in the
# hub, which forwards GENEVE-encapsulated flows to the Cloud Connector pool.
#
# Prerequisites:
#   - zscaler_subnet_cidrs must be set (3 CIDRs, one per AZ)
#   - hub-vpc must expose zscaler_subnet_ids, zscaler_subnet_ids_list,
#     and zscaler_route_table_ids outputs
#   - Accept the Zscaler Cloud Connector Marketplace subscription before apply
#   - AWS Secrets Manager secret must exist before apply (see zscaler_cc_secret_name)
################################################################################

locals {
  cc_enabled = var.create_zscaler_cloud_connector

  # LB and target group names only allow alphanumeric characters and hyphens.
  cc_name = replace(var.name, "_", "-")

  # user_data passed to each Cloud Connector instance.
  # Format matches the [ZSCALER] block expected by Cloud Connector's init process.
  cc_user_data = local.cc_enabled ? join("\n", [
    "[ZSCALER]",
    "CC_URL=${var.zscaler_cc_prov_url}",
    "SECRET_NAME=${var.zscaler_cc_secret_name}",
    "HTTP_PROBE_PORT=${var.zscaler_cc_http_probe_port}",
  ]) : null

  # Flatten AZ × instance-index into a single map keyed by "<az>-<n>".
  # e.g. with 2 instances per AZ across 3 AZs → 6 entries:
  #   "us-east-1a-1", "us-east-1a-2", "us-east-1b-1", ...
  cc_instances = local.cc_enabled ? {
    for pair in flatten([
      for az, subnet_id in module.hub_vpc.zscaler_subnet_ids : [
        for i in range(var.zscaler_cc_instances_per_az) : {
          key       = "${az}-${i + 1}"
          az        = az
          subnet_id = subnet_id
        }
      ]
    ]) : pair.key => pair
  } : {}

  # Management SG list — non-empty only when a mgmt CIDR is provided.
  cc_mgmt_sg_id = local.cc_enabled && var.zscaler_cc_mgmt_cidr != "" ? [aws_security_group.zscaler_cc_mgmt[0].id] : []
}

# ─── Secrets Manager data source ─────────────────────────────────────────────
# Looked up by name so the IAM policy can scope GetSecretValue to the exact ARN.

data "aws_secretsmanager_secret" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0
  name  = var.zscaler_cc_secret_name
}

# ─── Cloud Connector IAM Policy ───────────────────────────────────────────────

resource "aws_iam_policy" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0

  name        = "${var.name}-zscaler-cc-policy"
  description = "Permissions required by Zscaler Cloud Connector instances"

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
        Resource = [data.aws_secretsmanager_secret.zscaler_cc[0].arn]
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

  tags = local.common_tags
}

# ─── Shared service-interface security group ──────────────────────────────────
# Controls what traffic the GWLB can forward to the Cloud Connector data plane.

resource "aws_security_group" "zscaler_cc_service" {
  count = local.cc_enabled ? 1 : 0

  name        = "${var.name}-zscaler-cc-service-sg"
  description = "Zscaler Cloud Connector service interface - GWLB GENEVE traffic"
  vpc_id      = module.hub_vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${var.name}-zscaler-cc-service-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "zscaler_cc_geneve" {
  count = local.cc_enabled ? 1 : 0

  security_group_id = aws_security_group.zscaler_cc_service[0].id
  description       = "GWLB GENEVE encapsulated traffic"
  from_port         = 6081
  to_port           = 6081
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "zscaler_cc_health" {
  count = local.cc_enabled ? 1 : 0

  security_group_id = aws_security_group.zscaler_cc_service[0].id
  description       = "GWLB health checks on http_probe_port"
  from_port         = var.zscaler_cc_http_probe_port
  to_port           = var.zscaler_cc_http_probe_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "zscaler_cc_service_all" {
  count = local.cc_enabled ? 1 : 0

  security_group_id = aws_security_group.zscaler_cc_service[0].id
  description       = "Allow all outbound from service interface"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

# ─── Management interface security group ─────────────────────────────────────
# Attached to eth1 (device_index=1). Only created when zscaler_cc_mgmt_cidr is set.

resource "aws_security_group" "zscaler_cc_mgmt" {
  count = local.cc_enabled && var.zscaler_cc_mgmt_cidr != "" ? 1 : 0

  name        = "${var.name}-zscaler-cc-mgmt-sg"
  description = "Zscaler Cloud Connector management interface - SSH access"
  vpc_id      = module.hub_vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${var.name}-zscaler-cc-mgmt-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "zscaler_cc_mgmt_ssh" {
  count = local.cc_enabled && var.zscaler_cc_mgmt_cidr != "" ? 1 : 0

  security_group_id = aws_security_group.zscaler_cc_mgmt[0].id
  description       = "SSH from management CIDR"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.zscaler_cc_mgmt_cidr

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "zscaler_cc_mgmt_all" {
  count = local.cc_enabled && var.zscaler_cc_mgmt_cidr != "" ? 1 : 0

  security_group_id = aws_security_group.zscaler_cc_mgmt[0].id
  description       = "Allow all outbound from management interface"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

# ─── Cloud Connector instances ────────────────────────────────────────────────
# for_each key = "<az>-<n>" (e.g. "us-east-1a-1"), value = { az, subnet_id }

module "zscaler_cc" {
  for_each = local.cc_instances

  source = "../../../boilerplate/modules/ec2-module" # adjust path as needed

  name          = "${var.name}-cc-${each.key}"
  ami_id        = var.zscaler_cc_ami_id
  instance_type = var.zscaler_cc_instance_type
  key_name      = var.zscaler_cc_key_name

  vpc_id    = module.hub_vpc.vpc_id
  subnet_id = each.value.subnet_id # eth0 — service/forwarding (device_index=0, GWLB targets this IP)

  # eth1 — management, same subnet (separate IP), attached post-launch
  secondary_subnet_id          = each.value.subnet_id
  secondary_security_group_ids = local.cc_mgmt_sg_id

  # Service SG (GENEVE + health check) on the primary/forwarding interface
  security_group_ids = [aws_security_group.zscaler_cc_service[0].id]

  # No ingress rules on the service interface — GWLB controls access via the service SG
  ingress_rules = []

  # Cloud Connector forwards traffic — disable source/dest check on both NICs
  source_dest_check = false

  # Grant Cloud Connector the permissions it needs beyond SSM
  additional_policy_arns = [aws_iam_policy.zscaler_cc[0].arn]
  create_ssm_role        = true

  user_data = local.cc_user_data

  root_volume_size      = 128
  root_volume_encrypted = true

  associate_public_ip = false

  tags = local.common_tags
}

# ─── Gateway Load Balancer ────────────────────────────────────────────────────

resource "aws_lb" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0

  name                             = "${local.cc_name}-cc-gwlb"
  load_balancer_type               = "gateway"
  subnets                          = module.hub_vpc.zscaler_subnet_ids_list
  enable_cross_zone_load_balancing = var.zscaler_cc_cross_zone_lb_enabled

  tags = merge(local.common_tags, { Name = "${local.cc_name}-cc-gwlb" })
}

# ─── GWLB target group (IP type, GENEVE port 6081) ───────────────────────────
# IP-type targeting sends GENEVE traffic directly to eth0 (the service/forwarding
# interface at device_index=0). Instance-type targeting cannot distinguish NICs.

resource "aws_lb_target_group" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0

  name        = "${local.cc_name}-cc-gwlb-tg"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = module.hub_vpc.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = tostring(var.zscaler_cc_http_probe_port)
    path                = "/?cchealth"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  stickiness {
    enabled = var.zscaler_cc_stickiness_enabled
    type    = "source_ip_dest_ip_proto"
  }

  tags = merge(local.common_tags, { Name = "${var.name}-cc-gwlb-tg" })
}

# Register each Cloud Connector's forwarding interface IP (eth0 / private_ip).
# eth0 is device_index=0 — the service/forwarding NIC that receives GENEVE traffic.
resource "aws_lb_target_group_attachment" "zscaler_cc" {
  for_each = local.cc_instances

  target_group_arn = aws_lb_target_group.zscaler_cc[0].arn
  target_id        = module.zscaler_cc[each.key].private_ip
  port             = var.zscaler_cc_http_probe_port
}

# ─── GWLB Listener ───────────────────────────────────────────────────────────

resource "aws_lb_listener" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0

  load_balancer_arn = aws_lb.zscaler_cc[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.zscaler_cc[0].arn
  }
}

# ─── GWLB Endpoints (one per AZ) ─────────────────────────────────────────────
# These endpoints are what spoke VPC route tables point to. Traffic sent to
# a GWLB endpoint is forwarded to the GWLB and on to Cloud Connector.

resource "aws_vpc_endpoint_service" "zscaler_cc" {
  count = local.cc_enabled ? 1 : 0

  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.zscaler_cc[0].arn]

  tags = merge(local.common_tags, { Name = "${var.name}-cc-gwlb-endpoint-svc" })
}

resource "aws_vpc_endpoint" "zscaler_cc" {
  for_each = local.cc_enabled ? module.hub_vpc.zscaler_subnet_ids : {}

  vpc_id            = module.hub_vpc.vpc_id
  service_name      = aws_vpc_endpoint_service.zscaler_cc[0].service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [each.value]

  tags = merge(local.common_tags, { Name = "${var.name}-cc-gwlb-endpoint-${each.key}" })
}
