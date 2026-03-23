locals {
  name = var.name

  # Resolve user data: explicit string > templatefile > null
  user_data = (
    var.user_data != null
    ? var.user_data
    : (
      var.user_data_templatefile != null
      ? templatefile(var.user_data_templatefile, var.user_data_vars)
      : null
    )
  )

  # Effective instance profile name
  instance_profile_name = (
    var.iam_instance_profile != null
    ? var.iam_instance_profile
    : (var.create_ssm_role ? aws_iam_instance_profile.ssm[0].name : null)
  )

  tags = merge({ Name = local.name }, var.tags)
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "this" {
  name        = "${local.name}-sg"
  description = "Managed by ec2-module for ${local.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for idx, r in var.ingress_rules : idx => r }

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = join(",", each.value.cidr_blocks)

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for idx, r in var.egress_rules : idx => r }

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = join(",", each.value.cidr_blocks)

  tags = local.tags
}

# ─── IAM / SSM ────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ssm" {
  count = var.iam_instance_profile == null && var.create_ssm_role ? 1 : 0

  name = "${local.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.iam_instance_profile == null && var.create_ssm_role ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.iam_instance_profile == null && var.create_ssm_role ? toset(var.additional_policy_arns) : toset([])

  role       = aws_iam_role.ssm[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.iam_instance_profile == null && var.create_ssm_role ? 1 : 0

  name = "${local.name}-ssm-profile"
  role = aws_iam_role.ssm[0].name

  tags = local.tags
}

# ─── Network Interfaces ───────────────────────────────────────────────────────

# Primary interface (eth0). Created explicitly so we can control source/dest check.
resource "aws_network_interface" "primary" {
  subnet_id         = var.subnet_id
  security_groups   = concat([aws_security_group.this.id], var.security_group_ids)
  source_dest_check = var.source_dest_check

  tags = merge(local.tags, { Name = "${local.name}-eni-primary" })
}

# Secondary interface (eth1) — optional, used for appliance data-plane traffic.
resource "aws_network_interface" "secondary" {
  count = var.secondary_subnet_id != null ? 1 : 0

  subnet_id         = var.secondary_subnet_id
  security_groups   = var.secondary_security_group_ids
  source_dest_check = false # Always disabled on appliance service interfaces

  tags = merge(local.tags, { Name = "${local.name}-eni-secondary" })
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile = local.instance_profile_name

  user_data = local.user_data

  ebs_optimized                        = var.ebs_optimized
  monitoring                           = var.detailed_monitoring
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior
  disable_api_termination              = var.disable_api_termination

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = var.root_volume_encrypted
    kms_key_id            = var.root_volume_kms_key_id
    delete_on_termination = true
  }

  # Primary interface — index 0
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.primary.id
  }

  # Secondary interface — index 1, only when configured
  dynamic "network_interface" {
    for_each = aws_network_interface.secondary
    content {
      device_index         = 1
      network_interface_id = network_interface.value.id
    }
  }

  tags = local.tags

  lifecycle {
    # AMI changes require replacement; make callers explicit about this.
    ignore_changes = [ami]
  }
}

# ─── Optional EIP (primary interface) ────────────────────────────────────────

resource "aws_eip" "primary" {
  count = var.associate_public_ip ? 1 : 0

  domain                    = "vpc"
  network_interface         = aws_network_interface.primary.id
  associate_with_private_ip = aws_network_interface.primary.private_ip

  tags = merge(local.tags, { Name = "${local.name}-eip" })

  depends_on = [aws_instance.this]
}

# ─── Target Group Registration (instance-type TGs) ───────────────────────────

resource "aws_lb_target_group_attachment" "this" {
  for_each = toset(var.target_group_arns)

  target_group_arn = each.value
  target_id        = aws_instance.this.id

  depends_on = [aws_instance.this]
}