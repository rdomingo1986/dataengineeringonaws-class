#!/usr/bin/env bash
# =====================================================================
# Carga manual no Redshift (FASE 1, antes do Step Functions).
#
# Faz: 1) roda o Glue job curated->dimensional e aguarda,
#      2) cria o schema (DDL) no Redshift via Data API,
#      3) COPY de cada tabela a partir do staging S3.
#
# Na FASE 2 isso é feito automaticamente pela State Machine.
#
# Uso: ./load-redshift.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DATA_BUCKET="aws-class-datalake-${ACCOUNT_ID}-${REGION}"
WG="aws-class-dw-wg"
DB="aws_class_dw"
COPY_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/aws-class-redshift-copy-role"
STAGE="s3://${DATA_BUCKET}/stage/redshift"

echo ">> 1) Rodando o Glue job curated->dimensional..."
RUN_ID="$(aws glue start-job-run --job-name aws-class-curated-to-dimensional \
  --region "$REGION" --query JobRunId --output text)"
echo "   JobRunId: $RUN_ID"
echo "   Aguarde o job terminar (SUCCEEDED) antes de prosseguir. Verifique com:"
echo "   aws glue get-job-run --job-name aws-class-curated-to-dimensional --run-id $RUN_ID --region $REGION --query 'JobRun.JobRunState' --output text"
echo
read -r -p "   Quando estiver em SUCCEEDED, pressione ENTER para criar o schema e fazer o COPY..."

echo ">> 2) Criando o schema (DDL) no Redshift..."
aws redshift-data batch-execute-statement --workgroup-name "$WG" --database "$DB" --region "$REGION" \
  --sqls \
  "CREATE TABLE IF NOT EXISTS dim_student (student_id VARCHAR(32) NOT NULL, student_name VARCHAR(256), student_email VARCHAR(256), region VARCHAR(16), country VARCHAR(8), PRIMARY KEY(student_id)) DISTSTYLE ALL;" \
  "CREATE TABLE IF NOT EXISTS dim_course (course_id VARCHAR(128) NOT NULL, course_name VARCHAR(256), PRIMARY KEY(course_id)) DISTSTYLE ALL;" \
  "CREATE TABLE IF NOT EXISTS fact_engagement (event_id VARCHAR(32) NOT NULL, student_id VARCHAR(32), course_id VARCHAR(128), event_type VARCHAR(32), event_ts VARCHAR(32), event_date DATE, study_minutes DOUBLE PRECISION, score DOUBLE PRECISION, engagement_level VARCHAR(16), is_completed BOOLEAN, PRIMARY KEY(event_id)) DISTKEY(student_id) SORTKEY(event_date);" \
  "TRUNCATE TABLE dim_student;" \
  "TRUNCATE TABLE dim_course;" \
  "TRUNCATE TABLE fact_engagement;"

echo "   (aguarde alguns segundos até o DDL terminar)"
sleep 8

echo ">> 3) COPY de cada tabela a partir do staging S3..."
aws redshift-data batch-execute-statement --workgroup-name "$WG" --database "$DB" --region "$REGION" \
  --sqls \
  "COPY dim_student FROM '${STAGE}/dim_student/' IAM_ROLE '${COPY_ROLE}' FORMAT AS CSV;" \
  "COPY dim_course FROM '${STAGE}/dim_course/' IAM_ROLE '${COPY_ROLE}' FORMAT AS CSV;" \
  "COPY fact_engagement FROM '${STAGE}/fact_engagement/' IAM_ROLE '${COPY_ROLE}' FORMAT AS CSV;"

echo ">> Pronto. Verifique no Query Editor v2:  SELECT COUNT(*) FROM fact_engagement;"
