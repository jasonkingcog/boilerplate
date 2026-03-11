# GuardDuty Organisation-Wide Enablement

Enables AWS GuardDuty across all accounts in a Control Tower organisation and exports findings to Microsoft Sentinel.

This is a **one-time operation**. Once applied, GuardDuty automatically enables itself on any new accounts added to the organisation. You only need to return to this code if you want to add coverage in additional AWS regions.

---

## What this deploys

### Per region — Security/Audit account
| Resource | Purpose |
|---|---|
| GuardDuty detector (management account) | Required before delegated admin can be designated |
| GuardDuty delegated admin | Hands organisation-wide control to the Security/Audit account |
| GuardDuty detector (Security/Audit account) | Central aggregator for all org findings |
| Organisation configuration | Auto-enables GuardDuty on all existing and future accounts |
| GuardDuty publishing destination | Wires GuardDuty to export findings cross-account to the Log Archive S3 bucket |

### Per region — Log Archive account
| Resource | Purpose |
|---|---|
| KMS key | Encrypts findings at rest (required by GuardDuty) and SQS messages in transit |
| S3 bucket | Receives exported findings from GuardDuty |
| SQS queue | Receives S3 event notifications — Sentinel polls this; encrypted with the findings KMS key |

### Once (global) — Log Archive account
| Resource | Purpose |
|---|---|
| Sentinel IAM role | Assumed by Microsoft Sentinel via OIDC to read findings from S3 and SQS |

### Enabled datasources
| Datasource | Enabled |
|---|---|
| Core threat detection (EC2, IAM, DNS) | Yes — always on |
| S3 Protection | Yes — detects threats targeting S3 buckets |
| EKS / Kubernetes audit logs | No |
| Malware Protection | No |

---

## Prerequisites

- Terraform >= 1.3.0
- The pipeline must authenticate directly to the management account (no role assumption needed for management — `AWSControlTowerExecution` does not exist there)
- The pipeline must be able to assume `AWSControlTowerExecution` in the Security/Audit and Log Archive accounts
- All three accounts must exist (created automatically by Control Tower)
- An OIDC identity provider for `sts.windows.net` must already exist in the Log Archive account (created when you first configured any Sentinel S3 connector there)
- Microsoft Sentinel must be configured with the **Amazon Web Services S3** data connector

---

## One-time setup

### Step 1 — Fill in the variables

Open [`terraform.tfvars`](terraform.tfvars) and replace the placeholder values:

| Variable | Where to find it |
|---|---|
| `security_account_id` | AWS Organizations console or Control Tower → Accounts |
| `security_account_role_arn` | Replace `REPLACE_WITH_SECURITY_ACCOUNT_ID` with your Security/Audit account ID |
| `log_archive_account_id` | AWS Organizations console or Control Tower → Accounts (pre-filled with `381709151858`) |
| `log_archive_account_role_arn` | Pre-filled — update if your Log Archive account ID differs |
| `sentinel_workspace_id` | Azure portal → Microsoft Sentinel → Settings → Workspace settings → Workspace ID |

> `security_account_role_arn` and `security_account_id` use the same Security/Audit account ID.
> `log_archive_account_role_arn` and `log_archive_account_id` use the same Log Archive account ID.
> No management account role is needed — the pipeline authenticates to the management account directly.

### Step 2 — Deploy

```bash
cd guardduty
terraform init
terraform plan
terraform apply
```

### Step 3 — Configure the Sentinel connector

After `terraform apply` completes, the **Outputs** section will show:

| Output | Use |
|---|---|
| `sentinel_role_arn` | Enter in Sentinel connector → "Role to assume" |
| `eu_west_2.sqs_queue_url` | Enter in Sentinel connector → SQS URL for eu-west-2 |
| `eu_west_1.sqs_queue_url` | Enter in Sentinel connector → SQS URL for eu-west-1 |

In Sentinel, add a queue entry per region. Each SQS queue corresponds to one region's findings bucket.

### Step 4 — Verify

Allow up to 24 hours for the first findings to appear (GuardDuty exports on a 6-hour batch cycle). Then query in Log Analytics:

```kql
AWSGuardDuty
| summarize Count = count() by Severity, Type
| sort by Count desc
```

---

## Adding a new region

To enable GuardDuty in an additional AWS region, three changes are required:

### 1 — Add provider aliases to [`providers.tf`](providers.tf)

```hcl
provider "aws" {
  alias  = "management_<region>"
  region = "<region>"
  # No assume_role — pipeline runs with management account credentials directly
}

provider "aws" {
  alias  = "security_<region>"
  region = "<region>"
  assume_role { role_arn = var.security_account_role_arn }
}

provider "aws" {
  alias  = "log_archive_<region>"
  region = "<region>"
  assume_role { role_arn = var.log_archive_account_role_arn }
}
```

### 2 — Add a module call to [`main.tf`](main.tf)

```hcl
module "guardduty_<region>" {
  source = "./modules/guardduty-region"

  providers = {
    aws.management  = aws.management_<region>
    aws.security    = aws.security_<region>
    aws.log_archive = aws.log_archive_<region>
  }

  security_account_id    = var.security_account_id
  log_archive_account_id = var.log_archive_account_id
  tags                   = var.tags
}
```

Also extend the Sentinel IAM role policy in `main.tf` to include the new region's bucket, queue and KMS key ARNs:

```hcl
# In the S3Read statement Resource list:
module.guardduty_<region>.findings_bucket_arn,
"${module.guardduty_<region>.findings_bucket_arn}/*",

# In the SQSRead statement Resource list:
module.guardduty_<region>.sqs_queue_arn,

# In the KMSDecrypt statement Resource list:
module.guardduty_<region>.findings_kms_key_arn,
```

### 3 — Add an output to [`outputs.tf`](outputs.tf)

```hcl
output "<region>" {
  description = "GuardDuty resources for <region>."
  value = {
    management_detector_id = module.guardduty_<region>.management_detector_id
    security_detector_id   = module.guardduty_<region>.security_detector_id
    findings_bucket_arn    = module.guardduty_<region>.findings_bucket_arn
    sqs_queue_url          = module.guardduty_<region>.sqs_queue_url
  }
}
```

Then run `terraform apply` and add the new SQS queue URL to the Sentinel connector.

---

## Architecture

```
Management Account (per region)
  └── GuardDuty detector
        └── Designates Security/Audit account as delegated admin

Security/Audit Account (per region)
  └── GuardDuty detector (org admin)
        └── Auto-enables all org accounts (existing + new)
        └── Publishing destination → cross-account write to Log Archive S3 bucket

Log Archive Account (per region)
  └── S3 bucket (KMS encrypted)
        └── S3 event notification → SQS queue
                                      └── Sentinel polls SQS
                                            └── Sentinel assumes OIDC IAM role
                                                  └── Sentinel reads S3
                                                        └── AWSGuardDuty table
```

---

## Repository structure

```
guardduty/
  providers.tf                    AWS provider aliases — one triple per region (management, security, log_archive)
  main.tf                         Module calls per region + Sentinel IAM role
  variables.tf                    Input variable definitions
  outputs.tf                      Detector IDs, bucket ARNs, SQS URLs, Sentinel role details
  terraform.tfvars                ← Fill in account IDs and Sentinel workspace ID
  README.md                       This file

  modules/
    guardduty-region/
      main.tf                     All GuardDuty resources for a single region
      variables.tf
      outputs.tf
```
