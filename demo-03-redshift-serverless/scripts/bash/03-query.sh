#!/usr/bin/env bash
# =====================================================================
# Demo 03 - Passo 3: executar consultas no Redshift via Data API.
# A Data API é assíncrona: executa, faz polling e traz o resultado.
#
# Uso:
#   ./03-query.sh "SELECT course, COUNT(*) FROM enrollments GROUP BY course"
#   ./03-query.sh          (sem argumento = consulta de exemplo padrão)
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="us-east-1"
WG="aws-class-rs-wg"
DB="aws_class_demo"

SQL="${1:-SELECT course, COUNT(*) AS matriculas, SUM(price) AS receita FROM enrollments GROUP BY course ORDER BY receita DESC}"

echo ">> Executando: $SQL"
QID="$(aws redshift-data execute-statement --workgroup-name "$WG" --database "$DB" \
  --region "$REGION" --sql "$SQL" --query Id --output text)"
echo "   StatementId: $QID"

while true; do
  sleep 2
  STATUS="$(aws redshift-data describe-statement --id "$QID" --region "$REGION" --query Status --output text)"
  case "$STATUS" in
    FINISHED) break ;;
    FAILED|ABORTED)
      echo ">> Erro:"
      aws redshift-data describe-statement --id "$QID" --region "$REGION" --query "Error" --output text
      exit 1 ;;
  esac
done

echo ">> Resultado:"
# Colunas
aws redshift-data get-statement-result --id "$QID" --region "$REGION" \
  --query "ColumnMetadata[].name" --output text
# Linhas (cada célula: primeiro valor não nulo dos tipos possíveis)
aws redshift-data get-statement-result --id "$QID" --region "$REGION" \
  --query "Records[*][*].[stringValue,longValue,doubleValue,booleanValue]" --output text
