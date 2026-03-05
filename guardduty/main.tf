# GuardDuty is a regional service — one module call per region.
# To add a region: add provider aliases in providers.tf, then add a module block here.

module "guardduty_eu_west_2" {
  source = "./modules/guardduty-region"

  providers = {
    aws.management  = aws.management_eu_west_2
    aws.security    = aws.security_eu_west_2
    aws.log_archive = aws.log_archive_eu_west_2
  }

  security_account_id    = var.security_account_id
  log_archive_account_id = var.log_archive_account_id
  tags                   = var.tags
}

module "guardduty_eu_west_1" {
  source = "./modules/guardduty-region"

  providers = {
    aws.management  = aws.management_eu_west_1
    aws.security    = aws.security_eu_west_1
    aws.log_archive = aws.log_archive_eu_west_1
  }

  security_account_id    = var.security_account_id
  log_archive_account_id = var.log_archive_account_id
  tags                   = var.tags
}

# ── OIDC Identity Provider (Log Archive account) ───────────────────────────────
# The Log Archive account already has an OIDC provider for sts.windows.net
# from an existing Sentinel S3 connector. Reference it via data source rather
# than creating a new one.

data "aws_iam_openid_connect_provider" "sentinel" {
  provider = aws.log_archive_eu_west_2
  arn      = "arn:aws:iam::${var.log_archive_account_id}:oidc-provider/sts.windows.net/33e01921-4d64-4f8c-a055-5bdaffd5e33d"
}

# ── Sentinel IAM Role (Log Archive account) ────────────────────────────────────
# IAM is global — created once in the Log Archive account where the findings
# buckets live. Grants Sentinel read access to findings across all regions.
#
# The role name MUST start with "OIDC_" — Microsoft Sentinel enforces this prefix.
# The RoleSessionName condition MUST start with "MicrosoftSentinel_".

resource "aws_iam_role" "sentinel_guardduty" {
  provider    = aws.log_archive_eu_west_2
  name        = "OIDC_MicrosoftSentinelGuardDuty"
  description = "Assumed by Microsoft Sentinel via OIDC to ingest GuardDuty findings from S3."
  tags        = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.sentinel.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "sts.windows.net/33e01921-4d64-4f8c-a055-5bdaffd5e33d/:aud" = "api://1462b192-27f7-4cb9-8523-0f4ecb54b47e"
            "sts:RoleSessionName"                                         = "MicrosoftSentinel_${var.sentinel_workspace_id}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sentinel_guardduty" {
  provider = aws.log_archive_eu_west_2
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
