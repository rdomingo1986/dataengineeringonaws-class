<#
.SYNOPSIS
  Coloca a data location do data lake em modo HIBRIDO.
.DESCRIPTION
  Coexistem IAM+S3 (Demo 01) e Lake Formation (Demo 02).
  E feito com deregister + register porque update-resource nao suporta
  locations com service-linked role.
.EXAMPLE
  .\enable-hybrid.ps1
  .\enable-hybrid.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

$AccountId = (aws sts get-caller-identity --query Account --output text)
$BucketArn = "arn:aws:s3:::aws-class-datalake-$AccountId-$Region"

Write-Host ">> Desregistrando a location..."
aws lakeformation deregister-resource --resource-arn $BucketArn --region $Region

Write-Host ">> Registrando de novo em modo HIBRIDO..."
aws lakeformation register-resource --resource-arn $BucketArn `
    --use-service-linked-role --hybrid-access-enabled --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao registrar em modo hibrido." }

Write-Host ">> Estado atual:"
aws lakeformation describe-resource --resource-arn $BucketArn --region $Region `
    --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
Write-Host ">> Pronto. A Demo 01 (IAM) e a Demo 02 (LF) convivem. De alguns segundos de propagacao."
