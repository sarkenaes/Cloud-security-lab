# AWS Purple Team Cloud Security Lab

> A deliberately vulnerable AWS environment built to simulate real world cloud attacks and demonstrate automated detection and response. 
---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Vulnerabilities Built](#vulnerabilities-built)
- [Attack Scripts](#attack-scripts)
- [Detection Layer](#detection-layer)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup & Deployment](#setup--deployment)
- [Key Security Concepts](#key-security-concepts)
- [Future Enhancements](#future-enhancements)


---

## Overview

This project deploys an intentionally misconfigured AWS environment, attacks it using real techniques, and detects those attacks using AWS-native security tooling.

**The three phases:**

1. **Build** — Deploy vulnerable infrastructure using Terraform (misconfigured IAM, open security groups, public S3 buckets, exposed databases)
2. **Attack** — Exploit those misconfigurations using Python/boto3 scripts simulating real attacker techniques (S3 exfiltration, IMDS credential theft)
3. **Detect** — Catch those attacks using CloudTrail, CloudWatch, and SNS alerting

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Account                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │                  VPC (10.0.0.0/16)               │  │
│  │                                                  │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │           Public Subnet (0.0.0.0/0)        │  │  │
│  │  │                                            │  │  │
│  │  │  ┌──────────────┐    ┌──────────────────┐  │  │  │
│  │  │  │  EC2 Instance│    │   RDS MySQL      │  │  │  │
│  │  │  │  (t3.micro)  │    │  (publicly       │  │  │  │
│  │  │  │              │    │   accessible)    │  │  │  │
│  │  │  │ ┌──────────┐ │    └──────────────────┘  │  │  │
│  │  │  │ │IAM Role  │ │                           │  │  │
│  │  │  │ │(Admin    │ │                           │  │  │
│  │  │  │ │Access)   │ │                           │  │  │
│  │  │  │ └──────────┘ │                           │  │  │
│  │  │  └──────────────┘                           │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  │                                                  │  │
│  │  S3 Bucket (public) ──── fake sensitive files    │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐   │  │
│  │  │           Detection Layer                │   │  │
│  │  │  CloudTrail → CloudWatch → SNS → Email   │   │  │
│  │  └──────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘

Attack Path 1: Attacker → S3 bucket (no credentials needed)
Attack Path 2: Attacker → SSH into EC2 → IMDS → steal credentials → use from anywhere
```

> See `/docs/architecture.png` for the full visual diagram.

---

## Vulnerabilities Built

| Resource | Misconfiguration | Risk |
|---|---|---|
| Security Group | All ports open to `0.0.0.0/0` inbound and outbound | EC2 directly reachable from anywhere on the internet |
| EC2 Instance | Public subnet + `map_public_ip_on_launch = true` | Auto assigned public IP, no network isolation |
| IAM Role | `AdministratorAccess` attached to EC2 instance profile | Full AWS account takeover if EC2 is compromised |
| S3 Bucket | Public access block disabled + `Principal: "*"` bucket policy | Unauthenticated data exfiltration by anyone |
| RDS Database | `publicly_accessible = true`, no encryption, `password123` | Database reachable from internet with trivial credentials |
| Networking | Route table sends `0.0.0.0/0` to internet gateway | No traffic restrictions in or out of the subnet |

---

## Attack Scripts

### 1. S3 Enumeration & Exfiltration

**File:** `attacks/s3_enum.py`

**What it demonstrates:** Unauthenticated data exfiltration from a public S3 bucket.No AWS account or credentials required. A real external attacker can download sensitive files directly from the internet.

**Technique:**
- Uses `botocore.UNSIGNED` to make completely unauthenticated requests -simulating an attacker with zero AWS access
- Guesses common sensitive filenames rather than listing 
- Downloads successful guesses to a local `exfiltrated/` directory
- Handles failed guesses  without crashing

**Run it:**
```bash
mkdir -p exfiltrated
python3 attacks/s3_enum.py
```

**Screenshot:** *(see `/docs/screenshots/s3_exfiltration.png`)*

**Real-world parallel:** This technique was used in the Capital One breach (2019) and multiple Facebook data exposures.The companies accidentally misconfigured S3 public access settings and attackers exfiltrated sensitive data without ever authenticating to AWS.

---

### 2. IMDS Credential Theft

**Files:** `attacks/IMDS.py` + `attacks/use_stolen_creds.py`

**What it demonstrates:** Full EC2 Instance Metadata Service (IMDS) credential theft from gaining access to an EC2 instance, through stealing its live IAM credentials, to using those credentials remotely to prove full account takeover.

**How IMDS works:** Every EC2 instance has a special internal-only address (`169.254.169.254`) that serves live AWS credentials for whatever IAM role is attached to the instance. Any code running ON the instance can query this address  This becomes dangerous when the instance is compromised and the attached role has excessive permissions.

**Attack chain:**

Phase 1 — Run on the EC2 instance (`IMDS.py`):
```
Request IMDSv2 token
        ↓
Query IMDS: "what role am I?"  →  cloud-security-lab-ec2-role
        ↓
Query IMDS: "give me credentials for that role"
        ↓
Receive: AccessKeyId + SecretAccessKey + SessionToken
```

Phase 2 — Run locally on attacker's machine (`use_stolen_creds.py`):
```
Use stolen credentials from own laptop
        ↓
Call iam:ListUsers
        ↓
Successfully lists all IAM users → proves AdministratorAccess
```

**Run it:**
```bash
# Get EC2 public IP
terraform output ec2_public_ip

# Copy script to EC2
scp -i ~/.ssh/cloud-lab-key attacks/IMDS.py ubuntu@YOUR_EC2_IP:~/

# SSH in and run
ssh -i ~/.ssh/cloud-lab-key ubuntu@YOUR_EC2_IP
python3 IMDS.py

# Exit and use stolen credentials locally
exit
python3 attacks/use_stolen_creds.py
```

**Screenshot:** *(see `/docs/screenshots/imds_theft.png` and `/docs/screenshots/stolen_creds_proof.png`)*


**CloudTrail evidence:** The `iam:ListUsers` call made with stolen credentials showed up in CloudTrail with:
- `userIdentity.type: AssumedRole` (EC2 role credentials)
- `sourceIPAddress: [external laptop IP]` (not an AWS-internal address)
- Access key starting with `ASIA` (temporary STS credentials — a red flag when used externally)

*(see `/docs/screenshots/cloudtrail_evidence.png`)*

---

## Detection Layer

### CloudTrail
Logs every API call made in the AWS account — who, what, when, and from where. Delivers logs to both an S3 bucket (long-term archive) and CloudWatch Logs (real-time streaming for alerting).

Both attacks above were fully captured in CloudTrail event history, including the IMDS credential theft showing stolen credentials used from an external IP address.

### CloudWatch
Metric Filters scan the CloudTrail log stream in real time, watching for specific high-signal patterns. When a pattern is detected, a CloudWatch Alarm fires.

**Current alarms:**

| Alarm | Filter Pattern | What It Catches |
|---|---|---|
| `iam-create-user-alarm` | `{ $.eventName = "CreateUser" }` | Any new IAM user creation   |

### SNS Alerting
When a CloudWatch Alarm fires, an SNS notification is sent immediately to a subscribed email — real-time alerting without manual log review.

### Alert Flow
```
Suspicious API call occurs
        ↓
CloudTrail records the event
        ↓
CloudWatch Logs receives it in real time
        ↓
Metric Filter detects the pattern
        ↓
CloudWatch Alarm fires (threshold >= 1)
        ↓
SNS Topic publishes alert
        ↓
Email delivered immediately
```

*(see `/docs/screenshots/cloudwatch_alarm.png` and `/docs/screenshots/sns_alert_email.png`)*

---

## Tech Stack

| Category | Tools / Services |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS (us-east-1) |
| Attack Scripts | Python 3, boto3, botocore |
| Logging | AWS CloudTrail |
| Monitoring | AWS CloudWatch (Logs, Metric Filters, Alarms) |
| Alerting | AWS SNS |
| Compute | EC2 (Ubuntu 24.04, t3.micro) |
| Storage | S3 |
| Database | RDS MySQL (db.t3.micro) |
| Identity & Access | IAM (roles, policies, instance profiles) |
| Networking | VPC, public subnets, internet gateway, route tables, security groups |

---

## Project Structure

```
cloud-security-lab/
├── main.tf                  # Terraform provider and version config
├── variables.tf             # Input variables (project name, region)
├── outputs.tf               # Output values (EC2 public IP, etc.)
├── networking.tf            # VPC, subnets, IGW, route tables
├── iam.tf                   # IAM roles, policies, instance profiles
├── ec2.tf                   # EC2 instance, security group, SSH key pair
├── s3.tf                    # Vulnerable S3 bucket, public access config, bucket policy
├── rds.tf                   # RDS MySQL, subnet group
├── detection.tf             # CloudTrail, CloudWatch, SNS alerting
├── attacks/
│   ├── s3_enum.py           # Unauthenticated S3 enumeration and exfiltration
│   ├── IMDS.py              # EC2 IMDS credential theft (runs on EC2)
│   └── use_stolen_creds.py  # Remote proof using stolen IMDS credentials
├── fake-data/
│   ├── credentials.txt      # Fake AWS access keys
│   ├── employees.txt        # Fake employee PII
│   └── config.json          # Fake database credentials and API keys
└── docs/
    ├── architecture.png     # Architecture diagram
    └── screenshots/         # Evidence screenshots
```

---

## Setup & Deployment

### Prerequisites

- AWS account with CLI configured (`aws configure`)
- Terraform installed
- Python 3 + boto3 (`pip3 install boto3 --break-system-packages`)
- SSH key pair generated:

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/cloud-lab-key
```

### Deploy the environment

```bash
terraform init
terraform apply
```

> RDS takes 5-10 minutes to provision. This is normal.

### Run the S3 attack

```bash
mkdir -p exfiltrated
python3 attacks/s3_enum.py
```

### Run the IMDS attack

```bash
# Get EC2 IP from Terraform output
terraform output ec2_public_ip

# Copy script to EC2 and SSH in
scp -i ~/.ssh/cloud-lab-key attacks/IMDS.py ubuntu@EC2_IP:~/
ssh -i ~/.ssh/cloud-lab-key ubuntu@EC2_IP
python3 IMDS.py

# Exit back to local machine and prove stolen creds work
exit
python3 attacks/use_stolen_creds.py
```

### Destroy (run at the end of every session)

```bash
# Empty S3 buckets first (required before destroy)
aws s3 rm s3://cloud-security-lab-vulnerable-saron --recursive
aws s3 rm s3://saron-cloudtrail-logs --recursive

terraform destroy
```

---

## Security Concepts Demonstrated 

**Principle of Least Privilege** — EC2 has `AdministratorAccess` when it should have only the specific permissions needed for its job. A compromised instance with minimal permissions causes limited damage; one with admin access causes full account takeover.

**Defense in Depth** — Multiple overlapping misconfigurations compound each other. The IMDS attack requires BOTH an open security group (network access) AND an overprivileged IAM role (credential value) to be dangerous. Fixing either one breaks the attack chain.

**Assume Breach Mentality** — Building detection assuming the attacker will eventually get in, rather than relying purely on prevention. CloudTrail catches the credential misuse even when prevention failed.

**Credential Hygiene** — Temporary IMDS credentials being used from an external IP is a strong detection signal. Normal EC2 role usage originates from AWS's internal network — external usage is an immediate red flag.

**Shift-Left Security** — Infrastructure misconfigurations should be caught at the code level before deployment. Tools like Checkov and tfsec can scan Terraform files for these exact issues. *(planned enhancement)*

---

## Future Additions

- [ ] RDS exploitation script — connect to exposed database using weak credentials, demonstrate data access
- [ ] Additional CloudWatch alarms — S3 policy changes, security group modifications, IAM privilege escalation
- [ ] Lambda auto-remediation — automatically revoke suspicious credentials, re-lock public S3 buckets when alarms fire
- [ ] IAM privilege escalation attack script — demonstrate `iam:CreatePolicyVersion` escalation path
- [ ] React + Flask live dashboard — visualize detection findings and attack timeline in real time
- [ ] Prowler CIS Benchmark scan — before/after remediation comparison and security score
- [ ] Checkov Terraform scanning — shift-left security demonstration, catching misconfigs before deployment
- [ ] VPC Flow Logs — network-level visibility to complement CloudTrail API-level logging
- [ ] GuardDuty integration — automated ML-based threat detection layered on top of CloudWatch rules

---



---
