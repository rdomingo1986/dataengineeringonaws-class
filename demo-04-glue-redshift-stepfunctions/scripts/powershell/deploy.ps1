<#
.SYNOPSIS
  Implanta a Demo 04 (Redshift + modelo dimensional).
.DESCRIPTION
  Requer: AWS CLI configurado e a Demo 01 implantada (exports).
  Fluxo:
    1) cria o secret com a senha do Redshift (se nao existir)
    2) envia o script PySpark do Glue
    3) implanta o stack (Redshift Serverless + Glue job + State Machine)
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-redshift-demo -Region us-east-1
#>
param(
    [string]$StackName = "aws-class-redshift-demo",
    [string]$Region    = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId       = (aws sts get-caller-identity --query Account --output text)
$ArtifactsBucket = "aws-class-cfn-artifacts-$AccountId-$Region"

Write-Host ">> Stack:   $StackName"
Write-Host ">> Region:  $Region"

# 1) Secret com a senha de admin do Redshift (edite se quiser outra).
#    Deve atender a politica do Redshift: 8-64 chars, maiusc, minusc e numero.
aws secretsmanager create-secret --name aws-class-redshift-admin `
    --secret-string '{\"password\":\"AwsClassDemo2026\"}' --region $Region 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host ">> O secret ja existe, mantido." }

# 2) Enviar o script PySpark do Glue
Write-Host ">> Enviando o script do Glue..."
aws s3 cp src/glue/curated_to_dimensional.py `
    "s3://$ArtifactsBucket/src/glue/curated_to_dimensional.py" --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar o script do Glue." }

# 3) Implantar o stack
aws cloudformation deploy --template-file infra/redshift-stepfn-demo.yaml `
    --stack-name $StackName --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --parameter-overrides "ScriptsBucket=$ArtifactsBucket"
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao." }

Write-Host ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
