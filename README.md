# IaC Security Scanner

![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA)
![Checkov](https://img.shields.io/badge/Checkov-Scanner-blue)
![Trivy](https://img.shields.io/badge/Trivy-Scanner-1904DA)
![CI/CD](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF)

A hands-on demonstration of shift-left security: catching AWS misconfigurations in Terraform code *before* deployment, using automated scanning tools wired into a CI/CD pipeline.

## Overview

This project provisions a small, deliberately insecure AWS environment in Terraform, scans it with two independent security tools, remediates every finding it reasonably can, and gates the whole process behind a GitHub Actions pipeline that runs automatically on every push.

The goal isn't just "run a scanner" — it's to show the full lifecycle: **write → scan → interpret → fix → re-scan → automate.**

## Tools Used

- **Terraform** — Infrastructure as Code
- **Checkov** (Prisma Cloud) — static analysis security scanner
- **Trivy** (Aqua Security) — misconfiguration and vulnerability scanner
- **GitHub Actions** — CI/CD pipeline enforcement

> **Note on tool choice:** an earlier draft of this project used `tfsec`, but tfsec's check library was merged into Trivy in 2024 and is no longer actively maintained. Trivy was used instead as the current, supported equivalent.

## Repo Structure

```
iac-security-scanner/
├── terraform/
│   ├── insecure/
│   │   └── main.tf          # deliberately misconfigured AWS resources
│   └── secure/
│       └── main.tf          # remediated version
├── scan-results/            # raw JSON output from initial and final scans
├── screenshots/             # terminal and GitHub Actions evidence
└── .github/workflows/
    └── iac-scan.yml         # CI pipeline: runs Checkov + Trivy on every push
```

## What Was Built

Four resources, each with an intentional security flaw commonly seen in real AWS environments:

1. **S3 bucket** — public ACL, no encryption, no versioning, no logging
2. **Security group** — SSH (22) open to `0.0.0.0/0`, unrestricted egress
3. **IAM role policy** — wildcard `Action: "*"` / `Resource: "*"` (no least privilege)
4. **RDS instance** — hardcoded password, no encryption, no deletion protection, 1-day backup retention

## Results: Before vs. After

| Tool | Before | After | Reduction |
|---|---|---|---|
| **Trivy** | 16 findings (1 CRITICAL, 8 HIGH, 4 MEDIUM, 3 LOW) | 3 findings (1 CRITICAL, 1 HIGH, 1 LOW) | 81% |
| **Checkov** | 33 failed / 20 passed | 7 failed / 47 passed | 79% reduction in failures |

### Key fixes applied

| Issue | Fix |
|---|---|
| Public S3 bucket | ACL set to `private`; public access block fully enabled |
| No S3 encryption/versioning/logging | KMS encryption, versioning, and access logging enabled |
| Open security group (SSH from anywhere) | Ingress restricted to a single IP (`/32`); egress restricted to port 443 |
| IAM wildcard policy | Scoped to `s3:GetObject` / `s3:PutObject` on one specific bucket ARN only |
| Hardcoded RDS password | Replaced with a `sensitive` Terraform variable, supplied at runtime — never committed |
| RDS hygiene gaps | Encryption at rest, deletion protection, 7-day backups, auto minor-version upgrades, IAM auth, CloudWatch log exports all enabled |

### Accepted risk (remaining findings, left unresolved deliberately)

A handful of findings remain in the "secure" version, left unresolved as a deliberate cost/benefit call rather than an oversight:

- **RDS Multi-AZ, Enhanced Monitoring, Performance Insights** — real security/reliability value, but add ongoing cost disproportionate to a portfolio demo
- **S3 event notifications, lifecycle policy, cross-region replication** — operational hygiene, not security-critical
- **Security group not attached to a resource** — expected, since no EC2 instance was deployed to attach it to
- **Security group egress still flagged CRITICAL by Trivy** — egress was narrowed to port 443 only, but the CIDR block (`0.0.0.0/0`) is still open by IP, since the resource needs to reach arbitrary HTTPS endpoints. This is a real-world tradeoff between usability and strict lockdown, not an unresolved bug.

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/iac-scan.yml`) runs Checkov and Trivy automatically against **both** the insecure and secure Terraform configs on every push and pull request to `main`. This demonstrates the pipeline correctly identifying real issues in the insecure config while confirming the secure config's much smaller, accepted-risk footprint — without anyone needing to run a scanner manually.

Both jobs use `soft_fail` / `exit-code: 0` so the pipeline reports findings without hard-blocking the build. In a production setting, the secure job would typically be configured to fail on CRITICAL/HIGH findings once the accepted-risk list is formally signed off.

## A Note on the Visible Password

The hardcoded password shown in screenshots and scan output (`SuperSecretPassword123!`) is intentionally left unredacted. It's a placeholder created solely to demonstrate the hardcoded-secret misconfiguration — it was never used to protect any real resource, and the RDS instance itself was never deployed to a live AWS environment. Leaving it visible preserves accurate "before" evidence of the finding as the scanners actually reported it, rather than obscuring the very thing being demonstrated.

## What This Project Demonstrates

- Reading and interpreting security scanner output from two independent tools
- Applying least-privilege IAM principles in practice, not just in theory
- Understanding the difference between security-critical fixes and cost/operational tradeoffs
- Wiring security scanning into a CI/CD pipeline so it runs automatically, not manually
- Making and documenting deliberate risk-acceptance decisions — a core skill in real security work
