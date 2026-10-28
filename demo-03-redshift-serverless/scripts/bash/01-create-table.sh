#!/usr/bin/env bash
# =====================================================================
# Demo 03 - Passo 1: criar a tabela no Redshift via Data API.
# Cria a tabela 'enrollments' (matrículas de cursos da plataforma de cursos online).
#
# Uso: ./01-create-table.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"
WG="aws-class-rs-wg"
DB="aws_class_demo"

SQL="DROP TABLE IF EXISTS enrollments;
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
SORTKEY (enrolled_at);"

echo ">> Criando a tabela enrollments no Redshift via Data API..."
QID="$(aws redshift-data execute-statement --workgroup-name "$WG" --database "$DB" \
  --region "$REGION" --sql "$SQL" --query Id --output text)"

echo "   StatementId: $QID"
# Esperar até terminar
while true; do
  sleep 2
  STATUS="$(aws redshift-data describe-statement --id "$QID" --region "$REGION" --query Status --output text)"
  echo "   Status: $STATUS"
  case "$STATUS" in
    FINISHED) echo ">> Tabela criada."; break ;;
    FAILED|ABORTED)
      aws redshift-data describe-statement --id "$QID" --region "$REGION" --query "Error" --output text
      exit 1 ;;
  esac
done
