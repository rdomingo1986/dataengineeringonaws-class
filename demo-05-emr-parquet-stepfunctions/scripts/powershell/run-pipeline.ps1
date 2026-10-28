<#
.SYNOPSIS
  Demo 05 - Dispara manualmente a State Machine da ramificacao Parquet.
.DESCRIPTION
  Em producao ela dispara sozinha pelo evento do job cleaned->curated;
  este script serve para testar/demonstrar sem reexecutar o data lake.
.EXAMPLE
  .\run-pipeline.ps1
  .\run-pipeline.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

$AccountId = (aws sts get-caller-identity --query Account --output text)
$SmArn = "arn:aws:states:${Region}:${AccountId}:stateMachine:aws-class-emr-parquet-pipeline"

Write-Host ">> Iniciando a State Machine da ramificacao Parquet..."
aws stepfunctions start-execution --state-machine-arn $SmArn --region $Region `
    --query "executionArn" --output text
Write-Host ">> Acompanhe o progresso no console do Step Functions."
