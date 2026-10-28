<#
.SYNOPSIS
  Demo 05 - Implanta EMR Serverless + Parquet + Step Functions.
.DESCRIPTION
  1) envia o script PySpark do EMR ao S3
  2) implanta o stack (EMR app, crawler, State Machine, regra EventBridge)
  Requer: Demo 01 implantada (exports) e Demo 02 (bucket registrado no LF).
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-emr-parquet-demo -Region us-east-1
#>
param(
    [string]$StackName = "aws-class-emr-parquet-demo",
    [string]$Region    = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId       = (aws sts get-caller-identity --query Account --output text)
$ArtifactsBucket = "aws-class-cfn-artifacts-$AccountId-$Region"

Write-Host ">> Stack:  $StackName"
Write-Host ">> Bucket de scripts: $ArtifactsBucket"

Write-Host ">> Enviando o script PySpark do EMR..."
aws s3 cp src/emr/curated_json_to_parquet.py `
    "s3://$ArtifactsBucket/src/emr/curated_json_to_parquet.py" --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar o script do EMR." }

aws cloudformation deploy --template-file infra/emr-parquet-demo.yaml `
    --stack-name $StackName --capabilities CAPABILITY_NAMED_IAM `
    --region $Region --parameter-overrides "ScriptsBucket=$ArtifactsBucket"
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao." }

Write-Host ">> Outputs:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
