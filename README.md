# rails-aws-platform

A Rails 7 application running on AWS, provisioned with Terraform and deployed via GitHub Actions.

## Project structure

```
rails-aws-platform/
├── infra/                  Terraform infrastructure (VPC, EC2, RDS, ALB, ECR, IAM, OIDC)
├── app/                    Rails 7 Pokemon Battle API (see app/README.md)
└── .github/workflows/      CI/CD pipeline (test → build → deploy with manual approval)
```

## Architecture

- **VPC** with public/private subnets across two AZs
- **EC2** (Amazon Linux 2023) running Docker, in a public subnet
- **RDS MySQL 8.0** in private subnets, encrypted, credentials in Secrets Manager
- **ALB** in front of the EC2 instance on port 80 → 3000
- **ECR** for the Rails Docker image
- **IAM + GitHub OIDC** so CI/CD assumes a role instead of using long-lived keys
- **CloudWatch Logs** for the application

## Local development

The Rails app lives in `app/` and runs entirely in Docker — see [`app/README.md`](app/README.md) for the full walkthrough. Quick path:

```powershell
cd app
docker compose up -d --build
docker compose exec web bundle exec rails db:seed
curl.exe http://localhost:3000/health
```

Prerequisites: **Docker Desktop** (with WSL 2 backend on Windows). No local Ruby/MySQL needed.

## Deploy to AWS

### 1. Provision infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

### 2. Configure GitHub repo secrets

Capture the Terraform outputs and add them as repository secrets:

| Secret | Source |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | `terraform output -raw github_deploy_role_arn` |
| `AWS_REGION`          | `us-east-1` |
| `ECR_REPOSITORY`      | `terraform output -raw ecr_repository_url` |
| `EC2_INSTANCE_ID`     | `terraform output -raw ec2_instance_id` |
| `DB_SECRET_ARN`       | `terraform output -raw db_secret_arn` |

### 3. Configure the `production` GitHub environment

Repo settings → Environments → New environment → `production`. Add yourself as a required reviewer. The deploy job pauses here until approved.

### 4. Push to trigger the pipeline

```bash
git push origin main
```

The pipeline runs **test → build → deploy** (manual approval) → SSM into EC2 → docker pull → docker run with health check.

Pipeline behavior:
- Pushes/PRs to any branch run `test`
- PRs targeting `main` additionally run `build` (Dockerfile validation, no push to ECR)
- Pushes to `main` run all three jobs: test → build (push to ECR) → deploy (gated on approval)
- Workflow only triggers on changes to `app/**` or `.github/workflows/deploy.yml` — pure infra edits don't run it

## Cleanup

```bash
cd infra
terraform destroy
```

> The Secrets Manager secret has `recovery_window_in_days = 0` for dev convenience, so destroy is fully reversible. Raise this for production environments.
