<#
.SYNOPSIS
  Implanta a Demo 03 - Redshift Serverless (fundamentos).
.DESCRIPTION
  1) cria o secret com a senha de admin (se nao existir)
  2) implanta o stack (namespace + workgroup + papel COPY)
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-redshift-serverless-demo -Region us-east-1
#>
param(
    [string]$StackName = "aws-class-redshift-serverless-demo",
    [string]$Region    = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId  = (aws sts get-caller-identity --query Account --output text)
$DataBucket = "aws-class-cfn-artifacts-$AccountId-$Region"

Write-Host ">> Stack:  $StackName"
Write-Host ">> Region: $Region"
Write-Host ">> Bucket de dados: $DataBucket"

# Bucket de dados (reutiliza o de artefatos; cria se nao existir)
aws s3 mb "s3://$DataBucket" --region $Region 2>$null

# 1) Secret com a senha de admin (atende a politica do Redshift)
aws secretsmanager create-secret --name aws-class-rs-admin `
    --secret-string '{\"password\":\"AwsClassDemo2026\"}' --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host ">> O secret aws-class-rs-admin ja existe, mantido."
}

# 2) Implantar
aws cloudformation deploy --template-file infra/redshift-serverless.yaml `
    --stack-name $StackName --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --parameter-overrides "DataBucket=$DataBucket"
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao do stack." }

Write-Host ">> Outputs:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
