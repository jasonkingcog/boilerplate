region = "eu-west-2"

tags = {
  ManagedBy = "terraform"
  Team      = "identity"
}

# ── Permission Sets ────────────────────────────────────────────────────────────
# Define the permission sets your identity team manages.
# session_duration uses ISO 8601 format: PT1H = 1 hour, PT8H = 8 hours, PT12H = max.

permission_sets = {

  # Read-only access to all services — suitable for auditors and on-call observers.
  "ReadOnly" = {
    description               = "Read-only access to all AWS services."
    session_duration          = "PT4H"
    aws_managed_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    customer_managed_policies = []
    inline_policy_file        = null
  }

  # Power user — full access except IAM. Suitable for developers.
  "PowerUser" = {
    description               = "Full access to AWS services excluding IAM management."
    session_duration          = "PT8H"
    aws_managed_policy_arns   = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    customer_managed_policies = []
    inline_policy_file        = null
  }

  # Network admin — uses an AWS job function policy plus a customer-managed policy
  # that must be deployed to each target account (e.g. via the iam-role module).
  "NetworkAdmin" = {
    description      = "Full access to networking services."
    session_duration = "PT4H"
    aws_managed_policy_arns = [
      "arn:aws:iam::aws:policy/job-function/NetworkAdministrator"
    ]
    customer_managed_policies = [
      {
        name = "stw-prod-read-only"
        path = "/"
      }
    ]
    inline_policy = null
  }

  # Security auditor — AWS managed policy plus an inline policy for extra
  # permissions not covered by the managed policy.
  "SecurityAuditor" = {
    description      = "Read access to security and compliance services."
    session_duration = "PT2H"
    aws_managed_policy_arns = [
      "arn:aws:iam::aws:policy/SecurityAudit"
    ]
    customer_managed_policies = []
    inline_policy_file        = "./policies/security-auditor-inline.json"
  }
}

# ── Account Assignments ────────────────────────────────────────────────────────
# Grant each SCIM group access to one or more accounts via a permission set.
# group_name must exactly match the display name in IAM Identity Center.
# Add one entry per group + account combination.

assignments = [
  # platform-engineers get PowerUser in dev and staging
  {
    group_name          = "platform-engineers"
    account_id          = "111122223333"
    permission_set_name = "PowerUser"
  },
  {
    group_name          = "platform-engineers"
    account_id          = "444455556666"
    permission_set_name = "PowerUser"
  },

  # network-team gets NetworkAdmin in prod only
  {
    group_name          = "network-team"
    account_id          = "111122223333"
    permission_set_name = "NetworkAdmin"
  },

  # security-team gets SecurityAuditor across all accounts
  {
    group_name          = "security-team"
    account_id          = "111122223333"
    permission_set_name = "SecurityAuditor"
  },
  {
    group_name          = "security-team"
    account_id          = "444455556666"
    permission_set_name = "SecurityAuditor"
  },

  # all-staff get ReadOnly everywhere
  {
    group_name          = "all-staff"
    account_id          = "111122223333"
    permission_set_name = "ReadOnly"
  },
  {
    group_name          = "all-staff"
    account_id          = "444455556666"
    permission_set_name = "ReadOnly"
  },
]
