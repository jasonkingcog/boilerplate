output "management_detector_id" {
  description = "GuardDuty detector ID in the management account."
  value       = aws_guardduty_detector.management.id
}

output "security_detector_id" {
  description = "GuardDuty detector ID in the Security/Audit account."
  value       = aws_guardduty_detector.security.id
}

output "findings_bucket_arn" {
  description = "ARN of the S3 bucket receiving GuardDuty findings."
  value       = aws_s3_bucket.findings.arn
}

output "findings_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt findings."
  value       = aws_kms_key.findings.arn
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue receiving S3 event notifications."
  value       = aws_sqs_queue.findings.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue — provide this to the Sentinel S3 connector."
  value       = aws_sqs_queue.findings.url
}
