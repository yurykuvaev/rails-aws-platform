# Tear down the rails-aws-platform infrastructure cleanly so nothing keeps billing.
#
# What it does:
#   1. empties the ECR repo (terraform can't destroy a repo that has images)
#   2. terraform destroy in infra/
#
# What it intentionally does NOT do:
#   - GitHub repo secrets are left in place. They reference dead ARNs but cost
#     nothing; the next `up.ps1` run overwrites them.
#   - The `production` GitHub environment is left in place (also free).
#   - The S3 state bucket (tf-state-yury) is left in place; it holds state
#     for other projects too.

[CmdletBinding()]
param(
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

$caller = aws sts get-caller-identity --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "aws sts get-caller-identity failed. Is AWS auth configured?" }
Info "AWS account: $($caller.Account)  user: $($caller.Arn)"
Info "AWS region:  $Region"

if (-not $Yes) {
    Write-Host ""
    Write-Host "This will DESTROY all rails-aws-platform infrastructure in account $($caller.Account)." -ForegroundColor Yellow
    Write-Host "VPC, EC2, RDS (with all data), ALB, ECR images, NAT GW - all gone." -ForegroundColor Yellow
    $answer = Read-Host "Type 'destroy' to confirm"
    if ($answer -ne "destroy") { Write-Host "Aborted."; exit 0 }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$infraDir = Join-Path $repoRoot "infra"

# ----------------------------------------------
# 1. Empty ECR (terraform refuses to destroy non-empty repos)
# ----------------------------------------------
Step "Emptying ECR repository (if present)"
Push-Location $infraDir
try {
    Invoke-Native terraform @("init", "-input=false")

    # Pull repo URL from state; if state is gone or output missing, skip.
    $ecrUrl = $null
    try { $ecrUrl = terraform output -raw ecr_repository_url 2>$null } catch { }

    if ($ecrUrl) {
        $ecrName = $ecrUrl.Split('/')[-1]
        Info "Repository: $ecrName"

        $imagesJson = aws ecr list-images --repository-name $ecrName --region $Region --output json 2>$null
        if ($LASTEXITCODE -eq 0 -and $imagesJson) {
            $images = ($imagesJson | ConvertFrom-Json).imageIds
            if ($images -and $images.Count -gt 0) {
                Info "Deleting $($images.Count) image(s) from ECR"
                $argList = @(
                    "ecr", "batch-delete-image",
                    "--repository-name", $ecrName,
                    "--region", $Region,
                    "--image-ids"
                ) + ($images | ForEach-Object { "imageDigest=$($_.imageDigest)" })
                Invoke-Native aws $argList
            } else {
                Info "Repository is already empty."
            }
        } else {
            Info "No images found (or repo doesn't exist yet)."
        }
    } else {
        Info "No ECR repository in terraform state - skipping."
    }

    # ----------------------------------------------
    # 2. terraform destroy
    # ----------------------------------------------
    Step "terraform destroy (auto-approve)"
    Invoke-Native terraform @("destroy", "-input=false", "-auto-approve")
}
finally { Pop-Location }

Write-Host "`nAll AWS infrastructure destroyed. You will not be billed for it any more." -ForegroundColor Green
Write-Host "GitHub secrets and the production environment were left in place (no cost)." -ForegroundColor DarkGray
Write-Host "Run scripts\up.ps1 again to bring everything back." -ForegroundColor DarkGray
