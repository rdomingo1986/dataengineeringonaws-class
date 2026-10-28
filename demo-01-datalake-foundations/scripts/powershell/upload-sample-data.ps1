<#
.SYNOPSIS
  Envia os dados de amostra para o prefixo raw/ para disparar o pipeline.
.DESCRIPTION
  Se voce nao passar o bucket, ele e deduzido do padrao por conta/regiao.
.EXAMPLE
  .\upload-sample-data.ps1
  .\upload-sample-data.ps1 -Bucket aws-class-datalake-<ACCOUNT_ID>-us-east-1
#>
param(
    [string]$Bucket = "",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

if ([string]::IsNullOrEmpty($Bucket)) {
    $AccountId = (aws sts get-caller-identity --query Account --output text)
    $Bucket = "aws-class-datalake-$AccountId-$Region"
}

Write-Host ">> Enviando dados de amostra para s3://$Bucket/raw/student-events/"

aws s3 cp data/student-events-batch-1.json `
    "s3://$Bucket/raw/student-events/2026/03/01/student-events-batch-1.json" `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar o lote 1." }

aws s3 cp data/student-events-batch-2.json `
    "s3://$Bucket/raw/student-events/2026/03/02/student-events-batch-2.json" `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar o lote 2." }

Write-Host ">> Pronto. O EventBridge deve disparar os Glue jobs pelas notificacoes de evento."
Write-Host ">> Verifique cleaned/ e curated/ em alguns minutos (os Glue jobs levam ~1-2 min):"
Write-Host "   aws s3 ls s3://$Bucket/cleaned/student-events/ --recursive"
Write-Host "   aws s3 ls s3://$Bucket/curated/student-engagement/ --recursive"
