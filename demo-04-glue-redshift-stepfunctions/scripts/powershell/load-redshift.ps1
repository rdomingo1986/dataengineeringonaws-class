<#
.SYNOPSIS
  Carga manual no Redshift (FASE 1, antes do Step Functions).
.DESCRIPTION
  Faz: 1) roda o Glue job curated->dimensional e aguarda,
       2) cria o schema (DDL) no Redshift via Data API,
       3) COPY de cada tabela a partir do staging S3.
  Na FASE 2 isso e feito automaticamente pela State Machine.
.EXAMPLE
  .\load-redshift.ps1
  .\load-redshift.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

$AccountId  = (aws sts get-caller-identity --query Account --output text)
$DataBucket = "aws-class-datalake-$AccountId-$Region"
$Wg         = "aws-class-dw-wg"
$Db         = "aws_class_dw"
$CopyRole   = "arn:aws:iam::${AccountId}:role/aws-class-redshift-copy-role"
$Stage      = "s3://$DataBucket/stage/redshift"

Write-Host ">> 1) Rodando o Glue job curated->dimensional..."
$RunId = (aws glue start-job-run --job-name aws-class-curated-to-dimensional `
    --region $Region --query JobRunId --output text)
Write-Host "   JobRunId: $RunId"
Write-Host "   Aguarde o job terminar (SUCCEEDED) antes de prosseguir. Verifique com:"
Write-Host "   aws glue get-job-run --job-name aws-class-curated-to-dimensional --run-id $RunId --region $Region --query 'JobRun.JobRunState' --output text"
Write-Host ""
Read-Host "   Quando estiver em SUCCEEDED, pressione ENTER para criar o schema e fazer o COPY"

Write-Host ">> 2) Criando o schema (DDL) no Redshift..."
aws redshift-data batch-execute-statement --workgroup-name $Wg --database $Db --region $Region `
    --sqls `
    "CREATE TABLE IF NOT EXISTS dim_student (student_id VARCHAR(32) NOT NULL, student_name VARCHAR(256), student_email VARCHAR(256), region VARCHAR(16), country VARCHAR(8), PRIMARY KEY(student_id)) DISTSTYLE ALL;" `
    "CREATE TABLE IF NOT EXISTS dim_course (course_id VARCHAR(128) NOT NULL, course_name VARCHAR(256), PRIMARY KEY(course_id)) DISTSTYLE ALL;" `
    "CREATE TABLE IF NOT EXISTS fact_engagement (event_id VARCHAR(32) NOT NULL, student_id VARCHAR(32), course_id VARCHAR(128), event_type VARCHAR(32), event_ts VARCHAR(32), event_date DATE, study_minutes DOUBLE PRECISION, score DOUBLE PRECISION, engagement_level VARCHAR(16), is_completed BOOLEAN, PRIMARY KEY(event_id)) DISTKEY(student_id) SORTKEY(event_date);" `
    "TRUNCATE TABLE dim_student;" `
    "TRUNCATE TABLE dim_course;" `
    "TRUNCATE TABLE fact_engagement;"
if ($LASTEXITCODE -ne 0) { throw "Falha ao criar o schema." }

Write-Host "   (aguarde alguns segundos ate o DDL terminar)"
Start-Sleep -Seconds 8

Write-Host ">> 3) COPY de cada tabela a partir do staging S3..."
aws redshift-data batch-execute-statement --workgroup-name $Wg --database $Db --region $Region `
    --sqls `
    "COPY dim_student FROM '$Stage/dim_student/' IAM_ROLE '$CopyRole' FORMAT AS CSV;" `
    "COPY dim_course FROM '$Stage/dim_course/' IAM_ROLE '$CopyRole' FORMAT AS CSV;" `
    "COPY fact_engagement FROM '$Stage/fact_engagement/' IAM_ROLE '$CopyRole' FORMAT AS CSV;"
if ($LASTEXITCODE -ne 0) { throw "Falha no COPY." }

Write-Host ">> Pronto. Verifique no Query Editor v2:  SELECT COUNT(*) FROM fact_engagement;"
