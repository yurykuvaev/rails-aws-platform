# scripts/

Two PowerShell scripts to bring the whole platform up and tear it down without
needing an agent in the loop. Run from anywhere — they resolve paths relative
to themselves.

## Prerequisites (one-time)

- `terraform` ≥ 1.10 on PATH
- `aws` CLI authenticated (`aws sts get-caller-identity` works)
- `gh` CLI authenticated with `repo` + `workflow` scopes (`gh auth status`)

## Bring everything up

```powershell
.\scripts\up.ps1               # interactive confirmation
.\scripts\up.ps1 -Yes          # no prompt (CI / re-runs)
```

What it does:

1. `terraform init` + `terraform apply -auto-approve` in `infra/`
2. Reads outputs and writes 7 GitHub repo secrets (`AWS_DEPLOY_ROLE_ARN`,
   `AWS_REGION`, `ECR_REPOSITORY`, `EC2_INSTANCE_ID`, `DB_SECRET_ARN`,
   `RDS_ENDPOINT`, `RAILS_SECRET_KEY_BASE` — fresh 64-byte hex each run)
3. Upserts the `production` GitHub environment with no approval gate
4. Re-runs the latest `App CI/CD` workflow on `main` so the app deploys
5. Polls jobs until `deploy` finishes, then curls `http://<ALB>/health`

End-to-end takes ~10–12 minutes (RDS is the slow bit).

## Tear everything down

```powershell
.\scripts\down.ps1             # interactive confirmation (type 'destroy')
.\scripts\down.ps1 -Yes        # no prompt
```

What it does:

1. Empties the ECR repository (`terraform destroy` refuses on a non-empty repo)
2. `terraform destroy -auto-approve`

What it does NOT touch (intentional, all free):

- GitHub repo secrets — they reference dead ARNs after destroy. Harmless;
  next `up.ps1` overwrites them.
- The `production` GitHub environment.
- The S3 state bucket `tf-state-yury` (shared across projects).

After this completes you are no longer billed for ALB, NAT Gateway, RDS, EC2,
or the EIP — those are the resources that cost real money in this stack.
