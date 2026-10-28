<#
.SYNOPSIS
  Lanca uma consulta ao Redshift via Data API e mostra o resultado.
.DESCRIPTION
  A Data API e assincrona: executa, faz polling e traz o resultado.
  Formata a saida com o helper scripts/_format_result.py.
.EXAMPLE
  .\query-redshift.ps1 "SELECT COUNT(*) FROM fact_engagement"
  .\query-redshift.ps1          (sem argumento = consulta de contagens padrao)
#>
param(
    [string]$Sql = "SELECT (SELECT COUNT(*) FROM fact_engagement) AS fatos, (SELECT COUNT(*) FROM dim_student) AS estudantes, (SELECT COUNT(*) FROM dim_course) AS cursos",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
$Wg = "aws-class-dw-wg"
$Db = "aws_class_dw"

Write-Host ">> Executando: $Sql"
$Qid = (aws redshift-data execute-statement --workgroup-name $Wg --database $Db `
    --region $Region --sql $Sql --query Id --output text)
Write-Host "   StatementId: $Qid"

do {
    Start-Sleep -Seconds 2
    $Status = (aws redshift-data describe-statement --id $Qid --region $Region --query Status --output text)
    Write-Host "   Status: $Status"
    if ($Status -eq "FAILED" -or $Status -eq "ABORTED") {
        Write-Host ">> A consulta nao terminou bem. Detalhe do erro:"
        aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text
        throw "Consulta nao finalizou bem (status: $Status)."
    }
} while ($Status -ne "FINISHED")

Write-Host ">> Resultado:"
$Tmp = Join-Path $env:TEMP "rsresult.json"
aws redshift-data get-statement-result --id $Qid --region $Region --output json | Out-File -FilePath $Tmp -Encoding utf8
python (Join-Path $PSScriptRoot "..\_format_result.py") $Tmp
