# AWS-Secure-Iac-Pipeline-DRAFT

## Context and Business Impact

iCorp is a fictitious software company. The engineering team ships infrastructure to AWS multiple times a week using Terraform. A developer writes a module, it gets reviewed for functionality, does it create the right resources, does the application work and then it gets merged. Nobody checks whether the S3 bucket is public or whether the RDS database is encrypted.
<p></p>
The gap is not awareness, because developers know S3 buckets should not be public. The gap is process: there is no security gate that enforces these controls consistently.
<p></p>
These misconfigurations do not cause incidents immediately. They can sit quietly in production until a penetration test, compliance audit, or breach exposes them. By then, the cost can be significant.
<p></p>
iCorp needs an automated security pipeline that validates Terraform code before changes are merged. The pipeline will use Terraform validation using Checkov to identify misconfigurations, block unsafe pull requests, and upload findings in SARIF format to GitHub Code Scanning. This shifts security controls earlier in the development lifecycle (Shift Left), when problems are faster and cheaper to fix.
<p></p>

## Architecture


## Threat model (STRIDE)
To structure the security design, I used the STRIDE framework a simple but powerful way to think about threats in cloud environments.
<p></p>

| Category | Threat | Misconfiguration That Enables It | Checkov Control | Residual Risk |
|---|---|---|---|---|
| **Spoofing** | 	Attacker exploits an SSRF vulnerability on the EC2 app server to call the IMDSv1 metadata endpoint and retrieve the attached IAM role credentials without authentication — then impersonates the instance role | `http_tokens = "optional"`  IMDSv1 enabled on EC2 | `CKV_AWS_79` blocks IMDSv1 at pipeline gate | Low: pipeline blocks deployment of any instance with IMDSv1 |
| **Tampering** | Attacker with network access writes to an unversioned S3 bucket containing application configuration, overwrites files silently with no recovery path and no audit trail of the change | versioning block absent from aws_s3_bucket | `CKV_AWS_52` catches missing versioning | Low: versioning enforced before bucket reaches production |
| **Repudiation** | Attacker exfiltrates data from S3 and the activity leaves no trace because access logging is disabled, iCorp cannot prove what was accessed, when, or from where during a forensic investigation| logging block absent from aws_s3_bucket | `CKV_AWS_18` catches missing access logging | Medium: logging enforced by pipeline but CloudTrail integrity still depends on separate control |
| **Information Disclosure** | Attacker connects directly to the RDS instance from the internet using the master credentials no VPC, no security group required because the instance has a public endpoint | `publicly_accessible = true` on aws_db_instance | `CKV_AWS_17` catches public RDS | Low: pipeline blocks any RDS with public endpoint|
| **Denial of Service** | Attacker scans the public EC2 security group, finds port 22 open to 0.0.0.0/0, brute-forces SSH credentials or exploits an OpenSSH CVE to gain shell access and disrupt the instance | `cidr_blocks = ["0.0.0.0/0"]` on port 22 ingress rule | `CKV_AWS_25` catches open SSH |Low: pipeline blocks open ingress rules at CRITICAL severity |
| **Elevation of Privilege** | Attacker who compromises the EC2 instance finds the attached IAM role has Action: "*"  full AWS access, and pivots from a single compromised server to the entire AWS account | `Action = "*"` in aws_iam_role_policy | `CKV_AWS_274` catches wildcard IAM actions | Medium: pipeline blocks wildcard policies but role scoping still requires developer discipline post-remediation |

<p></p>

## Technical Steps

### 1. Infrastructure Setup



