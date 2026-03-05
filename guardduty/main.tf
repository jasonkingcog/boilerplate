# GuardDuty is a regional service — one module call per region.
# To add a region: add provider aliases in providers.tf, then add a module block here.

module "guardduty_eu_west_2" {
  source = "./modules/guardduty-region"

  providers = {
    aws.management = aws.management_eu_west_2
    aws.security   = aws.security_eu_west_2
  }

  security_account_id = var.security_account_id
  tags                = var.tags
}

module "guardduty_eu_west_1" {
  source = "./modules/guardduty-region"

  providers = {
    aws.management = aws.management_eu_west_1
    aws.security   = aws.security_eu_west_1
  }

  security_account_id = var.security_account_id
  tags                = var.tags
}

# ── Sentinel IAM Role ──────────────────────────────────────────────────────────
# IAM is global — created once in the Security account regardless of how many
# regions are enabled. Grants Sentinel read access to findings across all regions.

resource "aws_iam_role" "sentinel_guardduty" {
  provider    = aws.security_eu_west_2
  name        = "sentinel-guardduty-reader"
  description = "Assumed by Microsoft Sentinel to ingest GuardDuty findings from S3."
  tags        = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.sentinel_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.security_account_id}-sentinel-guardduty"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sentinel_guardduty" {
  provider = aws.security_eu_west_2
  name     = "sentinel-guardduty-access"
  role     = aws_iam_role.sentinel_guardduty.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Read"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          module.guardduty_eu_west_2.findings_bucket_arn,
          "${module.guardduty_eu_west_2.findings_bucket_arn}/*",
          module.guardduty_eu_west_1.findings_bucket_arn,
          "${module.guardduty_eu_west_1.findings_bucket_arn}/*",
        ]
      },
      {
        Sid    = "SQSRead"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          module.guardduty_eu_west_2.sqs_queue_arn,
          module.guardduty_eu_west_1.sqs_queue_arn,
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [
          module.guardduty_eu_west_2.findings_kms_key_arn,
          module.guardduty_eu_west_1.findings_kms_key_arn,
        ]
      }
    ]
  })
}
