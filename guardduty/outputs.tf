output "eu_west_2" {
  description = "GuardDuty resources for eu-west-2."
  value = {
    management_detector_id = module.guardduty_eu_west_2.management_detector_id
    security_detector_id   = module.guardduty_eu_west_2.security_detector_id
    findings_bucket_arn    = module.guardduty_eu_west_2.findings_bucket_arn
    sqs_queue_url          = module.guardduty_eu_west_2.sqs_queue_url
  }
}

output "eu_west_1" {
  description = "GuardDuty resources for eu-west-1."
  value = {
    management_detector_id = module.guardduty_eu_west_1.management_detector_id
    security_detector_id   = module.guardduty_eu_west_1.security_detector_id
    findings_bucket_arn    = module.guardduty_eu_west_1.findings_bucket_arn
    sqs_queue_url          = module.guardduty_eu_west_1.sqs_queue_url
  }
}

output "sentinel_role_arn" {
  description = "ARN of the IAM role for Sentinel to assume. Enter this in the Sentinel S3 connector under 'Role to assume'."
  value       = aws_iam_role.sentinel_guardduty.arn
}
