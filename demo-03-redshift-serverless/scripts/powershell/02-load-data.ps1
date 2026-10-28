<#
.SYNOPSIS
  Demo 03 - Passo 2: carregar dados com COPY a partir do S3 via Data API.
.DESCRIPTION
  1) envia o CSV de amostra ao S3
  2) executa COPY enrollments FROM 's3://...' com o papel de copia
.EXAMPLE
  .\02-load-data.ps1
  .\02-load-data.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
$Wg = "aws-class-rs-wg"
$Db = "aws_class_demo"

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId  = (aws sts get-caller-identity --query Account --output text)
$DataBucket = "aws-class-cfn-artifacts-$AccountId-$Region"
$CopyRole   = "arn:aws:iam::${AccountId}:role/aws-class-rs-copy-role"
$S3Key      = "demo03/enrollments.csv"

Write-Host ">> Enviando CSV para s3://$DataBucket/$S3Key"
aws s3 cp data/enrollments.csv "s3://$DataBucket/$S3Key" --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar o CSV." }

$Sql = "COPY enrollments FROM 's3://$DataBucket/$S3Key' IAM_ROLE '$CopyRole' FORMAT AS CSV;"

Write-Host ">> Executando COPY via Data API..."
$Qid = (aws redshift-data execute-statement --workgroup-name $Wg --database $Db `
    --region $Region --sql $Sql --query Id --output text)
Write-Host "   StatementId: $Qid"

while ($true) {
    Start-Sleep -Seconds 2
    $Status = (aws redshift-data describe-statement --id $Qid --region $Region --query Status --output text)
    Write-Host "   Status: $Status"
    switch ($Status) {
        "FINISHED" { Write-Host ">> Dados carregados."; return }
        "FAILED"   { aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text; throw "COPY falhou." }
        "ABORTED"  { aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text; throw "COPY abortado." }
    }
}
