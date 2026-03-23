# EC2 Module

A reusable Terraform module for deploying EC2 instances, with first-class support for network appliances and AWS Marketplace AMIs.

## Features

- Single- or dual-NIC instances (appliance/proxy deployments)
- Module-managed security group with configurable ingress/egress rules
- Elastic IP support tied to the primary ENI (survives stop/start)
- Encrypted root volume (gp3) by default
- SSM Session Manager IAM role created automatically
- User data via raw string or `templatefile()`
- Termination protection and source/destination check toggles
- Optional registration with instance-type NLB/ALB target groups

## Usage

### Minimal — single NIC

```hcl
module "ec2" {
  source = "git::https://github.com/your-org/ec2-module.git"

  name          = "my-instance"
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "t3.small"

  vpc_id    = "vpc-0abc123"
  subnet_id = "subnet-0abc123"

  tags = {
    Environment = "dev"
  }
}
```

### With ingress rules and a public IP

```hcl
module "ec2" {
  source = "git::https://github.com/your-org/ec2-module.git"

  name          = "bastion"
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
  key_name      = "my-key-pair"

  vpc_id              = "vpc-0abc123"
  subnet_id           = "subnet-0abc123"
  associate_public_ip = true

  ingress_rules = [
    {
      description = "SSH from corp"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["203.0.113.0/24"]
    }
  ]

  tags = {
    Environment = "prod"
  }
}

output "public_ip" {
  value = module.ec2.public_ip
}
```

### Dual-NIC network appliance (e.g. Zscaler VSE)

```hcl
module "appliance" {
  source = "git::https://github.com/your-org/ec2-module.git"

  name          = "zscaler-vse"
  ami_id        = "ami-0abcdef1234567890"  # Marketplace AMI
  instance_type = "c6i.large"

  vpc_id    = "vpc-0abc123"
  subnet_id = "subnet-mgmt"    # eth0 — management

  # eth1 — data-plane / service interface
  secondary_subnet_id          = "subnet-service"
  secondary_security_group_ids = ["sg-0service123"]

  # Appliances must forward traffic — disable source/dest check
  source_dest_check = false

  ingress_rules = [
    {
      description = "SSH from management CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

  # Inject sensitive provisioning credentials via templatefile
  user_data_templatefile = "${path.module}/user_data.tpl"
  user_data_vars = {
    provision_key = var.provision_key
    cloud_name    = "zscaler.net"
  }

  tags = {
    Role = "network-appliance"
  }
}
```

See [examples/zscaler-vse/](examples/zscaler-vse/) for a complete working example.

### Behind an NLB — instance-type target group

Use `target_group_arns` when the instance is the only NIC and the NLB targets it by instance ID:

```hcl
resource "aws_lb_target_group" "proxy" {
  name        = "my-proxy-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
}

module "proxy" {
  source = "git::https://github.com/your-org/ec2-module.git"

  name          = "my-proxy"
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "c6i.large"

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  source_dest_check = false

  target_group_arns = [aws_lb_target_group.proxy.arn]

  tags = { Role = "proxy" }
}
```

### Behind an NLB — IP-type target group (dual-NIC appliances)

When using a secondary interface (e.g. Zscaler VSE service plane), the NLB should use an **IP-type** target group aimed at `secondary_private_ip`. Register the target outside the module so the correct interface IP is used:

```hcl
resource "aws_lb_target_group" "vse" {
  name        = "vse-tg"
  port        = 9400
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

module "vse" {
  source = "git::https://github.com/your-org/ec2-module.git"

  name      = "zscaler-vse"
  ami_id    = "ami-0abcdef1234567890"
  vpc_id    = var.vpc_id
  subnet_id = var.mgmt_subnet_id

  secondary_subnet_id          = var.service_subnet_id
  secondary_security_group_ids = [var.service_sg_id]
  source_dest_check            = false

  # Do NOT set target_group_arns here — target the secondary IP instead.
  tags = { Role = "network-appliance" }
}

resource "aws_lb_target_group_attachment" "vse" {
  target_group_arn = aws_lb_target_group.vse.arn
  target_id        = module.vse.secondary_private_ip  # eth1
  port             = 9400
}
```

For a complete multi-AZ scaled deployment using `for_each` over AZ subnets, see the `core-network-hub` module.

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name` | Name prefix applied to all resources. | `string` | — | yes |
| `ami_id` | AMI ID to launch. Accept the Marketplace subscription first for Marketplace AMIs. | `string` | — | yes |
| `vpc_id` | VPC in which to create resources. | `string` | — | yes |
| `subnet_id` | Subnet for the primary network interface (eth0 / management). | `string` | — | yes |
| `instance_type` | EC2 instance type. | `string` | `"c6i.large"` | no |
| `key_name` | Existing EC2 key pair name. Omit to launch without SSH key access. | `string` | `null` | no |
| `associate_public_ip` | Allocate an Elastic IP on the primary interface. | `bool` | `false` | no |
| `secondary_subnet_id` | Subnet for a second NIC (eth1 / service). `null` for single-NIC instances. | `string` | `null` | no |
| `secondary_security_group_ids` | Security group IDs for the secondary interface. | `list(string)` | `[]` | no |
| `security_group_ids` | Additional existing SG IDs to attach to the primary interface. | `list(string)` | `[]` | no |
| `ingress_rules` | Ingress rules for the module-managed security group. | `list(object)` | `[]` | no |
| `egress_rules` | Egress rules for the module-managed security group. | `list(object)` | allow-all | no |
| `iam_instance_profile` | Existing IAM instance profile name. Overrides `create_ssm_role`. | `string` | `null` | no |
| `create_ssm_role` | Create an IAM role granting SSM Session Manager access. | `bool` | `true` | no |
| `root_volume_size` | Root EBS volume size in GiB. | `number` | `20` | no |
| `root_volume_type` | Root EBS volume type. | `string` | `"gp3"` | no |
| `root_volume_encrypted` | Encrypt the root EBS volume. | `bool` | `true` | no |
| `root_volume_kms_key_id` | KMS key ARN for root volume encryption. Uses AWS-managed key if omitted. | `string` | `null` | no |
| `ebs_optimized` | Launch as EBS-optimized. | `bool` | `true` | no |
| `user_data` | Raw user data string. Takes precedence over `user_data_templatefile`. | `string` | `null` | no |
| `user_data_templatefile` | Path to a templatefile rendered with `user_data_vars`. | `string` | `null` | no |
| `user_data_vars` | Variables passed to `user_data_templatefile`. | `map(string)` | `{}` | no |
| `detailed_monitoring` | Enable 1-minute CloudWatch monitoring. | `bool` | `false` | no |
| `disable_api_termination` | Enable termination protection. | `bool` | `false` | no |
| `instance_initiated_shutdown_behavior` | Shutdown behavior: `"stop"` or `"terminate"`. | `string` | `"stop"` | no |
| `source_dest_check` | Enable source/destination check. Set `false` for NAT/appliance instances. | `bool` | `true` | no |
| `target_group_arns` | ARNs of **instance-type** target groups to register this instance with. For IP-type target groups (e.g. targeting a secondary ENI), create the `aws_lb_target_group_attachment` externally using the `secondary_private_ip` output. | `list(string)` | `[]` | no |
| `tags` | Tags applied to all resources. | `map(string)` | `{}` | no |

### `ingress_rules` / `egress_rules` object schema

```hcl
{
  description = string
  from_port   = number
  to_port     = number
  protocol    = string        # "tcp", "udp", "icmp", or "-1" for all
  cidr_blocks = list(string)
}
```

---

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | EC2 instance ID. |
| `instance_arn` | EC2 instance ARN. |
| `private_ip` | Primary interface private IP address. |
| `public_ip` | Elastic IP address (`null` when `associate_public_ip = false`). |
| `primary_eni_id` | Primary network interface ID. |
| `secondary_eni_id` | Secondary network interface ID (`null` when not created). |
| `secondary_private_ip` | Secondary interface private IP (`null` when not created). |
| `security_group_id` | ID of the module-managed security group. |
| `iam_role_arn` | ARN of the auto-created SSM IAM role (`null` when an external profile is used). |

---

## Notes

### Marketplace AMIs

Before running `terraform apply` with a Marketplace AMI, accept the subscription manually in the AWS Console (EC2 → AMI Catalog → AWS Marketplace) or via the AWS CLI:

```bash
aws marketplace-catalog start-change-set ...
```

The AMI ID is region-specific. To find the latest for a given product:

```bash
aws ec2 describe-images \
  --owners aws-marketplace \
  --filters "Name=product-code,Values=<product-code>" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text
```

### AMI replacement

The module sets `ignore_changes = [ami]` on the instance so that updating `ami_id` in variables does not trigger an unintended replacement. To apply a new AMI, taint the resource explicitly:

```bash
terraform taint module.<name>.aws_instance.this
terraform apply
```

### Source/destination check

Set `source_dest_check = false` for any instance that forwards traffic on behalf of other hosts — NAT instances, proxies, load balancers, and network appliances like Zscaler VSE.

### Load balancer target group registration

The module supports two patterns depending on the target group type:

**Instance-type target groups** — use `target_group_arns`. The module creates `aws_lb_target_group_attachment` resources internally, registering the instance by ID. Suitable for single-NIC instances or when the primary interface handles load-balanced traffic.

**IP-type target groups** — do not use `target_group_arns`. Instead, create the `aws_lb_target_group_attachment` resource in the calling module using the `secondary_private_ip` output as `target_id`. This is required for dual-NIC appliances (e.g. Zscaler VSE) where the NLB must send traffic to the service interface (eth1), not the management interface (eth0). Passing an instance ID to an IP-type target group is invalid and will error.

### SSM access

By default the module creates an IAM role with `AmazonSSMManagedInstanceCore` attached, enabling console access via SSM Session Manager without requiring SSH or a bastion host. Set `create_ssm_role = false` to opt out, or supply your own profile via `iam_instance_profile`.

---

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.3.0 |
| AWS Provider | >= 5.0 |
