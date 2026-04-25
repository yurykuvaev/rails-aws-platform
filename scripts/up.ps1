# Provision the rails-aws-platform end-to-end:
#   1. terraform init/apply (infra/)
#   2. write all GitHub repo secrets from terraform outputs
#   3. ensure the `production` GitHub environment exists without approval gate
#   4. re-run the latest App CI/CD workflow on main so the app deploys
#   5. wait for the deploy to finish and curl the ALB /health endpoint
#
# Re-runnable: every step is idempotent (tf state is in S3, gh secret set
# overwrites, the environment PUT is upsert).

[CmdletBinding()]
param(
    [string]$Repo = "yurykuvaev/rails-aws-platform",
    [string]$Region = "us-east-1",
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

function Step([string]$msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Info([string]$msg) { Write-Host "  $msg" -ForegroundColor DarkGray }

function Require-Cmd([string]$name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $name"
    }
}

function Invoke-Native {
    param([string]$Exe, [string[]]$Args)
    & $Exe @Args
    if ($LASTEXITCODE -ne 0) {
        throw "$Exe $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

# ----------------------------------------------
# 0. Prerequisites
# ----------------------------------------------
Step "Checking prerequisites"
Require-Cmd terraform
Require-Cmd aws
Require-Cmd gh

$caller = aws sts get-caller-identity --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "aws sts get-caller-identity failed. Is AWS auth configured?" }
Info "AWS account: $($caller.Account)  user: $($caller.Arn)"
Info "AWS region:  $Region"
Info "GitHub repo: $Repo"

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh is not authenticated. Run: gh auth login" }

if (-not $Yes) {
    $answer = Read-Host "`nProceed with provisioning? (yes/no)"
    if ($answer -ne "yes") { Write-Host "Aborted."; exit 0 }
}

# ----------------------------------------------
# 1. Terraform
# ----------------------------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot
$infraDir = Join-Path $repoRoot "infra"
Push-Location $infraDir
try {
    Step "terraform init"
    Invoke-Native terraform @("init", "-input=false")

    Step "terraform apply (auto-approve)"
    Invoke-Native terraform @("apply", "-input=false", "-auto-approve")

    Step "Reading terraform outputs"
    $role = terraform output -raw github_deploy_role_arn
    $ecr  = terraform output -raw ecr_repository_url
    $ec2  = terraform output -raw ec2_instance_id
    $sec  = terraform output -raw db_secret_arn
    $rds  = terraform output -raw rds_endpoint
    $alb  = terraform output -raw alb_dns_name

    Info "ALB DNS:           $alb"
    Info "EC2 instance:      $ec2"
    Info "ECR repository:    $ecr"
}
finally { Pop-Location }

# ----------------------------------------------
# 2. GitHub secrets
# ----------------------------------------------
Step "Setting GitHub repo secrets"

# 64 random bytes (CSP-grade) -> 128 hex chars; rotated every up so a
# destroyed/re-created infra never reuses an old key with stale data.
$bytes = New-Object byte[] 64
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$rk = ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''

$secrets = [ordered]@{
    AWS_DEPLOY_ROLE_ARN   = $role
    AWS_REGION            = $Region
    ECR_REPOSITORY        = $ecr
    EC2_INSTANCE_ID       = $ec2
    DB_SECRET_ARN         = $sec
    RDS_ENDPOINT          = $rds
    RAILS_SECRET_KEY_BASE = $rk
}

foreach ($k in $secrets.Keys) {
    Info "  $k"
    $secrets[$k] | gh secret set $k --repo $Repo
    if ($LASTEXITCODE -ne 0) { throw "Failed to set secret $k" }
}

# ----------------------------------------------
# 3. production environment (no approval gate)
# ----------------------------------------------
Step "Ensuring production environment exists with no approval"
$envBody = @{
    wait_timer               = 0
    reviewers                = @()
    deployment_branch_policy = $null
} | ConvertTo-Json -Depth 5 -Compress

$envBodyFile = Join-Path $env:TEMP "rails-prod-env.json"
$envBody | Out-File -FilePath $envBodyFile -Encoding ascii
try {
    gh api --method PUT "repos/$Repo/environments/production" --input $envBodyFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to upsert production environment" }
}
finally { Remove-Item -Force -ErrorAction SilentlyContinue $envBodyFile }

# ----------------------------------------------
# 4. Trigger deploy by re-running the latest workflow on main
# ----------------------------------------------
Step "Triggering App CI/CD on main"
$runJson = gh run list --repo $Repo --branch main --workflow "App CI/CD" --limit 1 --json databaseId,headSha
if ($LASTEXITCODE -ne 0) { throw "gh run list failed" }
$runs = $runJson | ConvertFrom-Json

if (-not $runs -or $runs.Count -eq 0) {
    Write-Warning "No previous App CI/CD run found on main. Push any change under app/ to trigger the pipeline."
    Write-Host "`nInfra is ready. Once a workflow runs, the app will deploy automatically." -ForegroundColor Yellow
    Write-Host "ALB URL: http://$alb" -ForegroundColor Green
    exit 0
}

$runId = $runs[0].databaseId
Info "Re-running run $runId (commit $($runs[0].headSha.Substring(0,7)))"
gh run rerun $runId --repo $Repo
if ($LASTEXITCODE -ne 0) { throw "gh run rerun failed" }

# ----------------------------------------------
# 5. Poll until deploy completes
# ----------------------------------------------
Step "Waiting for deploy to finish"
$deadline = (Get-Date).AddMinutes(15)
$lastStatus = ""
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 15
    $jobs = (gh run view $runId --repo $Repo --json jobs | ConvertFrom-Json).jobs
    if (-not $jobs) { continue }

    $line = ($jobs | ForEach-Object { "$($_.name)=$($_.status)/$($_.conclusion)" }) -join "  "
    if ($line -ne $lastStatus) { Info $line; $lastStatus = $line }

    $deploy = $jobs | Where-Object { $_.name -eq "deploy" }
    if ($deploy -and $deploy.status -eq "completed") {
        if ($deploy.conclusion -ne "success") {
            throw "Deploy job finished with conclusion: $($deploy.conclusion). See: https://github.com/$Repo/actions/runs/$runId"
        }
        break
    }

    $failed = $jobs | Where-Object { $_.conclusion -eq "failure" }
    if ($failed) {
        throw "Job '$($failed[0].name)' failed. See: https://github.com/$Repo/actions/runs/$runId"
    }
}

# ----------------------------------------------
# 6. Health check
# ----------------------------------------------
Step "Health check"
$ok = $false
for ($i = 1; $i -le 12; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://$alb/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Info "HTTP 200 - $($resp.Content)"
            $ok = $true
            break
        }
    } catch {
        Info "Attempt ${i}: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 5
}
if (-not $ok) { Write-Warning "ALB did not return 200 within 60s. Check the EC2 logs." }

Write-Host "`nDone. App URL: http://$alb" -ForegroundColor Green
