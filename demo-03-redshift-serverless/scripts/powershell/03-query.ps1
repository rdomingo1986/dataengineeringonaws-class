<#
.SYNOPSIS
  Demo 03 - Passo 3: executar consultas no Redshift via Data API.
.DESCRIPTION
  A Data API e assincrona: executa, faz polling e traz o resultado.
.EXAMPLE
  .\03-query.ps1 "SELECT course, COUNT(*) FROM enrollments GROUP BY course"
  .\03-query.ps1          (sem argumento = consulta de exemplo padrao)
#>
param(
    [string]$Sql = "SELECT course, COUNT(*) AS matriculas, SUM(price) AS receita FROM enrollments GROUP BY course ORDER BY receita DESC",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
$Wg = "aws-class-rs-wg"
$Db = "aws_class_demo"

Write-Host ">> Executando: $Sql"
$Qid = (aws redshift-data execute-statement --workgroup-name $Wg --database $Db `
    --region $Region --sql $Sql --query Id --output text)
Write-Host "   StatementId: $Qid"

do {
    Start-Sleep -Seconds 2
    $Status = (aws redshift-data describe-statement --id $Qid --region $Region --query Status --output text)
    if ($Status -eq "FAILED" -or $Status -eq "ABORTED") {
        Write-Host ">> Erro:"
        aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text
        throw "Consulta nao finalizou bem (status: $Status)."
    }
} while ($Status -ne "FINISHED")

Write-Host ">> Resultado:"
# Colunas
aws redshift-data get-statement-result --id $Qid --region $Region `
    --query "ColumnMetadata[].name" --output text
# Linhas (cada celula: primeiro valor nao nulo dos tipos possiveis)
aws redshift-data get-statement-result --id $Qid --region $Region `
    --query "Records[*][*].[stringValue,longValue,doubleValue,booleanValue]" --output text
