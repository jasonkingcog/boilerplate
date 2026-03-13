# SSO Permission Sets

This directory manages IAM Identity Center permission sets. Each permission set is defined in its own `.tf` file and controls what a group of users can do across one or more AWS accounts.

## Prerequisites

Before creating a permission set, confirm the following:

- The IAM Identity Center group already exists and is being synced via SCIM. Contact the Identity team if the group is not yet present.
- You know the AWS account IDs (or OU ID) the permission set should be assigned to.
- You have reviewed what level of access is appropriate and confirmed it with the relevant team lead.

---

## Creating a new permission set

### 1. Create a new `.tf` file

Name the file after the permission set, e.g. `readonly-finance.tf`. Do not add to an existing file.

### 2. Add a module block

Copy the template below and fill in the required values:

```hcl
module "<unique_module_name>" {
  source = "../../modules/sso-permission-set"

  name        = "<permission-set-name>"
  description = "<what this grants and any restrictions>"

  group_name = "<exact display name of the IAM Identity Center group>"

  # Optional: attach one or more AWS-managed policies.
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  # Optional: define a custom inline policy for additional allow or deny rules.
  # Use jsonencode() — do not reference an external JSON file.
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "<descriptive statement ID>"
        Effect   = "Allow" # or "Deny"
        Action   = "<service:Action or list>"
        Resource = "*"
      }
    ]
  })

  # List the account IDs this permission set should be assigned to.
  account_ids = [
    "111122223333",
    "444455556666",
  ]

  session_duration = "PT1H" # ISO 8601 format, max PT12H

  tags = {
    Team        = "<team name>"
    Environment = "prod"
  }
}

output "<unique_module_name>_permission_set_arn" {
  description = "ARN of the <permission-set-name> permission set."
  value       = module.<unique_module_name>.permission_set_arn
}

output "<unique_module_name>_assigned_account_ids" {
  description = "Accounts the <permission-set-name> permission set was assigned to."
  value       = module.<unique_module_name>.assigned_account_ids
}
```

### 3. Field reference

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Name of the permission set as it will appear in IAM Identity Center. Must be unique across the organisation. |
| `description` | No | Plain English description of what access is granted and any restrictions. |
| `group_name` | Yes | Exact display name of the SCIM-synced group in IAM Identity Center. Case-sensitive. |
| `aws_managed_policy_arns` | No | List of AWS-managed policy ARNs to attach (e.g. `ReadOnlyAccess`, `PowerUserAccess`). |
| `inline_policy` | No | A single custom policy defined inline using `jsonencode()`. Use this for additional allows or explicit denies not covered by AWS-managed policies. |
| `account_ids` | Yes | List of AWS account IDs to assign this permission set to. At least one required. |
| `session_duration` | No | How long a session lasts after login. Defaults to `PT1H`. Max `PT12H`. |
| `tags` | No | Tags applied to the permission set resource. |

At least one of `aws_managed_policy_arns` or `inline_policy` must be provided.

### 4. Targeting an entire OU instead of individual accounts

If the permission set should apply to all accounts within an Organisational Unit, use the `aws_organizations_organizational_unit_descendant_accounts` data source instead of listing accounts manually:

```hcl
data "aws_organizations_organizational_unit_descendant_accounts" "target_ou" {
  parent_id = "ou-xxxx-xxxxxxxx"
}

module "<unique_module_name>" {
  source = "../../modules/sso-permission-set"

  ...

  account_ids = data.aws_organizations_organizational_unit_descendant_accounts.target_ou.accounts[*].id
}
```

New accounts added to the OU will be picked up automatically on the next pipeline run.

---

## Removing a permission set

To remove a permission set and all its account assignments, delete the corresponding `.tf` file and raise a pull request. The pipeline will destroy the resources on the next apply.

Do not manually delete permission sets in the AWS console — they will be recreated on the next pipeline run.

---

## Existing permission sets

| File | Permission Set Name | Group | Notes |
|---|---|---|---|
| `readonly-cyber.tf` | `readonly-cyber` | `readonly-cyber` | ReadOnly across all accounts; S3 denied outside cyber accounts |
| `readonly-network.tf` | `readonly-network` | `readonly-network` | ReadOnly across all accounts |
