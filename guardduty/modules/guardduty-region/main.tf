terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0.0"
      configuration_aliases = [aws.management, aws.security]
    }
  }
}

# Used to name region-specific resources (e.g. S3 bucket, KMS alias)
data "aws_region" "current" {
  provider = aws.security
}

# ── Management Account ─────────────────────────────────────────────────────────

resource "aws_guardduty_detector" "management" {
  provider = aws.management
  enable   = true
  tags     = var.tags
}

resource "aws_guardduty_organization_admin_account" "this" {
  provider         = aws.management
  admin_account_id = var.security_account_id

  depends_on = [aws_guardduty_detector.management]
}

# ── Security / Audit Account (delegated admin) ─────────────────────────────────

resource "aws_guardduty_detector" "security" {
  provider = aws.security
  enable   = true
  tags     = var.tags

  depends_on = [aws_guardduty_organization_admin_account.this]
}

resource "aws_guardduty_organization_configuration" "this" {
  provider                         = aws.security
  detector_id                      = aws_guardduty_detector.security.id
  auto_enable_organization_members = "ALL"

  datasources {
    # S3 Protection — detects threats targeting S3 buckets (API activity, policy changes)
    s3_logs {
      auto_enable = true
    }
  }
}

# ── KMS Key ────────────────────────────────────────────────────────────────────
# GuardDuty requires findings to be KMS-encrypted at rest.

resource "aws_kms_key" "findings" {
  provider                = aws.security
  description             = "GuardDuty findings encryption — ${data.aws_region.current.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.security_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowGuardDutyEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = ["kms:GenerateDataKey", "kms:Encrypt"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "findings" {
  provider      = aws.security
  name          = "alias/guardduty-findings-${data.aws_region.current.name}"
  target_key_id = aws_kms_key.findings.key_id
}

# ── S3 Bucket ──────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "findings" {
  provider = aws.security
  bucket   = "guardduty-findings-${var.security_account_id}-${data.aws_region.current.name}"
  tags     = var.tags
}

resource "aws_s3_bucket_versioning" "findings" {
  provider = aws.security
  bucket   = aws_s3_bucket.findings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "findings" {
  provider = aws.security
  bucket   = aws_s3_bucket.findings.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.findings.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "findings" {
  provider                = aws.security
  bucket                  = aws_s3_bucket.findings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "findings" {
  provider = aws.security
  bucket   = aws_s3_bucket.findings.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGuardDutyPutObject"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.findings.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AllowGuardDutyGetBucketLocation"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.findings.arn
      },
      {
        Sid       = "DenyNonSecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.findings.arn,
          "${aws_s3_bucket.findings.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ── SQS Queue ──────────────────────────────────────────────────────────────────
# Receives S3 event notifications — Sentinel polls this to know when new
# findings have landed in S3.

resource "aws_sqs_queue" "findings" {
  provider                   = aws.security
  name                       = "guardduty-findings-${data.aws_region.current.name}"
  message_retention_seconds  = 86400 # 24 hours
  visibility_timeout_seconds = 300
  tags                       = var.tags
}

resource "aws_sqs_queue_policy" "findings" {
  provider  = aws.security
  queue_url = aws_sqs_queue.findings.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3SendMessage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.findings.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.findings.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "findings" {
  provider = aws.security
  bucket   = aws_s3_bucket.findings.id

  queue {
    queue_arn = aws_sqs_queue.findings.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.findings]
}

# ── GuardDuty Publishing Destination ──────────────────────────────────────────

resource "aws_guardduty_publishing_destination" "this" {
  provider        = aws.security
  detector_id     = aws_guardduty_detector.security.id
  destination_arn = aws_s3_bucket.findings.arn
  kms_key_arn     = aws_kms_key.findings.arn

  depends_on = [
    aws_s3_bucket_policy.findings,
    aws_kms_key.findings
  ]
}
