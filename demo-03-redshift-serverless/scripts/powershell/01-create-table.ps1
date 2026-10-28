<#
.SYNOPSIS
  Demo 03 - Passo 1: criar a tabela no Redshift via Data API.
.DESCRIPTION
  Cria a tabela 'enrollments' (matriculas de cursos da plataforma de cursos online).
.EXAMPLE
  .\01-create-table.ps1
  .\01-create-table.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
$Wg = "aws-class-rs-wg"
$Db = "aws_class_demo"

$Sql = @"
DROP TABLE IF EXISTS enrollments;
CREATE TABLE enrollments (
  enrollment_id INTEGER NOT NULL,
  student_name  VARCHAR(256),
  course        VARCHAR(128),
  region        VARCHAR(16),
  enrolled_at   DATE,
  status        VARCHAR(16),
  price         DECIMAL(10,2),
  PRIMARY KEY (enrollment_id)
)
DISTSTYLE AUTO
SORTKEY (enrolled_at);
"@

Write-Host ">> Criando a tabela enrollments no Redshift via Data API..."
$Qid = (aws redshift-data execute-statement --workgroup-name $Wg --database $Db `
    --region $Region --sql $Sql --query Id --output text)
Write-Host "   StatementId: $Qid"

# Esperar ate terminar (polling)
while ($true) {
    Start-Sleep -Seconds 2
    $Status = (aws redshift-data describe-statement --id $Qid --region $Region --query Status --output text)
    Write-Host "   Status: $Status"
    switch ($Status) {
        "FINISHED" { Write-Host ">> Tabela criada."; return }
        "FAILED"   { aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text; throw "Comando falhou." }
        "ABORTED"  { aws redshift-data describe-statement --id $Qid --region $Region --query "Error" --output text; throw "Comando abortado." }
    }
}
