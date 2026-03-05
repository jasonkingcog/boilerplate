# AWS Identity Boilerplate

Terraform and CloudFormation code for managing AWS IAM Identity Center access across a Control Tower landing zone.

---

## How to grant a group access to an AWS account

This is the day-to-day task for the identity team. All access is controlled through a single file:

**[`test-claude/terraform.tfvars`](test-claude/terraform.tfvars)**

There are two things you may need to do: create a **permission set** (if one doesn't already exist for the level of access required) and add an **account assignment** (to grant a group that access).

---

### Step 1 — Check if a suitable permission set already exists

Open [`test-claude/terraform.tfvars`](test-claude/terraform.tfvars) and look at the `permission_sets` block at the top. Common ones already defined:

| Name | What it allows |
|---|---|
| `ReadOnly` | Read-only access to all AWS services |
| `PowerUser` | Full access except IAM management |
| `NetworkAdmin` | Full networking access |
| `SecurityAuditor` | Security and compliance read access |

If one of these fits, skip to Step 2. If not, continue below.

---

### Step 1a — Create a new permission set (if needed)

Add a new entry to the `permission_sets` block in `terraform.tfvars`. Each permission set supports three policy types — use whichever combination you need:

```hcl
"MyNewPermissionSet" = {
  description      = "Description of what this grants."
  session_duration = "PT4H"   # Max session length. PT1H=1hr, PT8H=8hrs, PT12H=max.

  # AWS-managed policies — attach by ARN. Available in all accounts automatically.
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  # Customer-managed policies — referenced by name. Must be deployed to each
  # target account separately before this permission set will work.
  customer_managed_policies = [
    {
      name = "my-custom-policy"
      path = "/"
    }
  ]

  # Inline policy — path to a JSON file in test-claude/policies/.
  # Set to null if not needed.
  inline_policy_file = "./policies/my-new-inline.json"
}
```

> **Note on customer-managed policies:** If you reference a customer-managed policy by name, that policy must already exist in every AWS account you assign this permission set to. Use the `iam-role` module (see [`modules/iam-role/`](modules/iam-role/)) to deploy it.

> **Note on inline policies:** Create a JSON file in [`test-claude/policies/`](test-claude/policies/) and reference its path. See [`test-claude/policies/security-auditor-inline.json`](test-claude/policies/security-auditor-inline.json) for an example.

---

### Step 2 — Add an account assignment

Scroll down to the `assignments` block in `terraform.tfvars` and add a new entry:

```hcl
{
  group_name          = "my-group"        # Must exactly match the group display name in IAM Identity Center
  account_id          = "123456789012"    # 12-digit AWS account ID
  permission_set_name = "ReadOnly"        # Must match a key in the permission_sets block above
},
```

To grant the same group access to multiple accounts, add one entry per account:

```hcl
{
  group_name          = "my-group"
  account_id          = "111122223333"
  permission_set_name = "ReadOnly"
},
{
  group_name          = "my-group"
  account_id          = "444455556666"
  permission_set_name = "ReadOnly"
},
```

---

### Step 3 — Apply

```bash
cd test-claude
terraform init    # only needed on first run or after provider changes
terraform plan    # review what will change
terraform apply
```

Access is granted immediately after `apply` completes. Users in the group will see the new account appear in the AWS access portal.

---

## Repository structure

```
modules/
  iam-role/                   Terraform module — creates an IAM role with attached policies
  sso-permission-set/         Terraform module — creates a permission set and assigns it to accounts

examples/
  s3-reader/                  Example: deploy an IAM role for EC2 S3 read access
  sso-permission-set/         Example: grant an SSO group access via a customer-managed policy

test-claude/
  main.tf                     SSO resources (permission sets, policy attachments, assignments)
  variables.tf                Variable definitions
  terraform.tfvars            ← Edit this file to manage access
  providers.tf                AWS provider config (targets management account)
  outputs.tf                  Permission set ARNs and group IDs
  policies/                   Inline policy JSON files

example-iam-policies/         Example IAM policy JSON files for reference

cloudformation/
  sentinel-cloudtrail-ingestion.yaml    Sets up CloudTrail → CloudWatch Logs delivery for Sentinel
```

---

## Prerequisites

- Terraform >= 1.3.0
- AWS credentials for the **management account** (IAM Identity Center lives here)
- The group must already exist in IAM Identity Center (synced via SCIM from your IdP)
- For customer-managed policy references: the policy must be pre-deployed to each target account
