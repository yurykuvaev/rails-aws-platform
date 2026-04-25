# infra/

Terraform infrastructure for **rails-aws-platform**.

## Architecture

```
                    Internet
                       │
                  ┌────▼────┐
                  │   ALB   │      public subnets (1a, 1b)
                  │  :80    │
                  └────┬────┘
                       │ :3000
                  ┌────▼────┐
                  │   EC2   │      public subnet 1a
                  │ Docker  │      reachable via SSM Session Manager (no SSH)
                  └────┬────┘
                       │ :3306
                  ┌────▼────┐
                  │   RDS   │      private subnets (1a, 1b)
                  │ MySQL 8 │      encrypted, credentials in Secrets Manager
                  └─────────┘

  ECR ──── docker pull ────► EC2
  Secrets Manager ──── GetSecretValue ────► EC2 (DB creds)
  GitHub Actions ──── AssumeRoleWithWebIdentity (OIDC) ────► AWS
```

## Resources

| File | What |
|---|---|
| `versions.tf`     | Terraform 1.5+, AWS ~> 5.0, Random ~> 3.0 |
| `variables.tf`    | `aws_region`, `environment`, `project_name`, `github_repo` |
| `networking.tf`   | VPC, IGW, NAT GW, public/private subnets, route tables |
| `security.tf`     | Security groups: `alb`, `ec2`, `rds` (chained by SG ID) |
| `ec2.tf`          | AL2023 AMI, t3.small, user_data installs Docker + ECR login |
| `rds.tf`          | MySQL 8.0, db.t3.micro, password generated and stored in Secrets Manager |
| `alb.tf`          | ALB, target group on port 3000, `/health` health check |
| `ecr.tf`          | ECR repo with scan-on-push |
| `iam.tf`          | EC2 instance role: SSM, ECR pull, Secrets Manager read |
| `cloudwatch.tf`   | Log group `/rails-app/dev`, 30-day retention |
| `github_oidc.tf`  | OIDC provider + deploy role scoped to `repo:<github_repo>:ref:refs/heads/main` |
| `outputs.tf`      | ALB DNS, ECR URL, EC2 instance ID/IP, RDS endpoint, secret ARN, deploy role ARN |

## Setup

```bash
terraform init
terraform plan
terraform apply
```

## Outputs to capture

After `terraform apply`, run:

```bash
terraform output -raw github_deploy_role_arn   # → secret AWS_DEPLOY_ROLE_ARN
terraform output -raw ecr_repository_url       # → secret ECR_REPOSITORY
terraform output -raw ec2_instance_id          # → secret EC2_INSTANCE_ID
terraform output -raw db_secret_arn            # → secret DB_SECRET_ARN
```

`AWS_REGION` is whatever you set in `var.aws_region` (default `us-east-1`).

## Cleanup

```bash
terraform destroy
```

> The Secrets Manager secret has a recovery window. If you plan to re-apply soon after destroy, either pass `-recovery-window-in-days=0` via the AWS CLI on the orphaned secret, or add `recovery_window_in_days = 0` to `aws_secretsmanager_secret.db` before destroy.
