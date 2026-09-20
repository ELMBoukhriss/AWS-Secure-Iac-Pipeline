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

The first step is to make sure that the following tools are installed.

```
terraform --version
git --version
checkov --version
```
<p></p>
<img width="400" height="200" alt="1" src="/assets/1.png" />
<p></p>

### 1. Create the Github Repo
```
# Create local project
mkdir aws-icorp-iac-pipeline
cd aws-icorp-iac-pipeline
git init
git branch -M main

# Create folder structure
mkdir -p terraform .github/workflows

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform — never commit these
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.auto.tfvars

EOF
```
The next step is to create the github repo.
```
git remote add origin https://github.com/ELMBoukhriss/aws-icorp-iac-pipeline.git
```

### 2. Misconfigured Terraform files

This terraform infrastructure files contain several misconfigurations that will be detected by checkov scan.
<p></p>

| Terraform file | Description |
|---|---|
| **[main.tf](terraform/main.tf)**| Provider config, Terraform version, shared data sources (AMI, account ID) |
| **[variables.tf](terraform/variables.tf)**| Input variables : region, project name, DB credentials | 
| **[outputs.tf](terraform/outputs.tf)** | Exposes VPC ID and S3 bucket name after apply |
| **[vpc.tfvars](terraform/vpc.tf)**  | VPC, internet gateway, public subnet, route table | 
| **[sg.tf](terraform/sg.tf)**  | 	Security groups for EC2 and RDS, intentionally misconfigured with open ingress rules | 
| **[iam.tf](terraform/iam.tf)**  | EC2 instance role, intentionally misconfigured with wildcard Action: "*" |
| **[ec2.tf](terraform/ec2.tf)** | App server: intentionally misconfigured with IMDSv1 and unencrypted EBS|
| **[s3.tf](terraform/s3.tf)**  | Application data bucket: intentionally misconfigured with public access enabled | 
| **[rds.tf](terraform/rds.tf)**  | PostgreSQL database: intentionally misconfigured, unencrypted and publicly accessible |

<p></p>

### 3. Github Actions Pipeline

we need to create ".github/workflows/security-pipeline.yml" [Security-pipeline.yml](security-pipeline.yml) file wich will be the blueprint for our pipeline.

*Triggers*

Runs automatically on every pull request and push targeting main

*Permissions*

Requests only 3 permissions — read code, write PR comments, write to Security tab

*Job 1: Terraform Format*

Checks all .tf files are correctly formatted
Fails if any file needs formatting, enforces consistent code style

*Job 2: Terraform Validate*

Checks Terraform syntax and resource schema are valid
Runs without AWS credentials, purely static analysis

*Job 3: Checkov Security Scan*

Scans all Terraform files using checkov
Outputs results to the Actions log and uploads a SARIF file to the GitHub Security tab
Posts a findings summary table as a comment directly on the PR

*Job 4: Security Gate*

The only job added to branch protection as a required status check
Fails if Checkov failed, errored, or was skipped, closes the bypass gap
If it fails, the PR is blocked and cannot be merged

<p></p>

### 4. Local Checkov test

Before wiring GitHub Actions, i will validate the i can see the findings locally using checkov:

```
# confirm terraform files are valid
cd terraform
terraform init -backend=false
terraform validate
cd ..

# confirm checkov finds issues
checkov -d terraform/ --framework terraform --quiet
```
<p></p>
<img width="900" height="800" alt="1" src="/assets/2.png" />
<p></p>

### 5. Commit the Misconfigured State

I will push the misconfigured infrastructure to the main branch of the repo aws-icorp-iac-pipeline.

```
git remote add origin https://github.com/ELMBoukhriss/aws-icorp-iac-pipeline.git

git add .
git commit -m "ci: add pipeline and misconfigured infrastructure"
git push -u origin main

```
After that i will create a feature branch named "misconfigured-infra" and add a comment "# trigger" to the main.tf file, this way we will simulate the push of a new version of the iac code to the main branch from the misconfigured-infra branch.
```
git checkout -b feat/misconfigured-infra
echo " # trigger" >> terraform/main.tf
git add .
git commit -m "feat: misconfigured infrastructure baseline"
git push -u origin feat/misconfigured-infra
```
<p></p>
<img width="900" height="800" alt="1" src="/assets/3.png" />
<p></p>

Now i will go to github and create a pull request from "misconfigured-infra" branch to "main" branch.

<p></p>
<img width="900" height="800" alt="1" src="/assets/4.png" />
<p></p>

<p></p>
<img width="900" height="800" alt="1" src="/assets/5.png" />
<p></p>

After creating the pull request, we can notice in the image below, that the Terraform Validate and Format jobs were successful, but the Checkov Scan and Security gate weren't. Which means that checkov has detected some misconfigurations in our IaC code.

<p></p>
<img width="900" height="800" alt="1" src="/assets/6.png" />
<p></p>

As we can see in the github actions section, The IaC has 42 security findings that we need to resolve before merging.
<p></p>
The table shows the Rule code for example `CKV_AWS_126`, in the newt column we find a short remediation recommendation, then the file column shows the filename and code line number.

<p></p>
<img width="900" height="800" alt="1" src="/assets/7.png" />
<p></p>


### 6. Enabling Branch Protection

I will enable the `main` branch protection rule, so that no code can be merged without validating our security checks.

<p></p>
<img width="900" height="800" alt="1" src="/assets/8.png" />
<p></p>

The needed configurations are numbered in the screenshot below.

<p></p>
<img width="900" height="1000" alt="1" src="/assets/9.png" />
<p></p>


### 7. Fixing the Terraform and merging the code

The files that needs to be fixed are `sg.tf`, `iam.tf`, `ec2.tf`, `s3`, `rds.tf`, `vpc.tf`. The others have no checkov findings.

**Fixed Files**
[sg.tf](/terraform-fixed/sg.tf)
[iam.tf](/terraform-fixed/iam.tf)
[ec2.tf](/terraform-fixed/ec2.tf)
[s3.tf](/terraform-fixed/s3.tf)
[rds.tf](/terraform-fixed/rds.tf)
[vpc.tf](/terraform-fixed/vpc.tf)

### 7. Enabling Branch Protection

After fixing the misconfigurations i will retest with checkov locally

<p></p>
<img width="900" height="800" alt="1" src="/assets/10.png" />
<p></p>

We can notice that 13 findings remain unresolved. For this lab scenario i will explicitly skip them in our security pipeline file.

```
Add this code to the security-pipeline.yml file

          skip_check: >-
            CKV_AWS_288,
            CKV_AWS_355,
            CKV_AWS_290,
            CKV_AWS_353,
            CKV_AWS_157,
            CKV_AWS_118,
            CKV2_AWS_11,
            CKV2_AWS_12,
            CKV2_AWS_62,
            CKV_AWS_144,
            CKV2_AWS_61,
            CKV_AWS_145,
            CKV2_AWS_30
```

<p></p>
<img width="900" height="800" alt="1" src="/assets/11.png" />
<p></p>


