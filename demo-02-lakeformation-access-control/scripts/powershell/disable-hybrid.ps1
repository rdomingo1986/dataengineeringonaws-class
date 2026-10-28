<#
.SYNOPSIS
  Coloca a data location do data lake em modo SO LAKE FORMATION.
.DESCRIPTION
  Os papeis da Demo 01 (IAM+S3) deixam de poder ler; so os principals
  com grants do Lake Formation acessam os dados.
  E feito com deregister + register (nao com CloudFormation).
.EXAMPLE
  .\disable-hybrid.ps1
  .\disable-hybrid.ps1 -Region us-east-1
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

Write-Host ">> Registrando de novo em modo SO LAKE FORMATION..."
aws lakeformation register-resource --resource-arn $BucketArn `
    --use-service-linked-role --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao registrar em modo so-LF." }

Write-Host ">> Estado atual:"
aws lakeformation describe-resource --resource-arn $BucketArn --region $Region `
    --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
Write-Host ">> Pronto. So os papeis com grants do Lake Formation podem ler."
