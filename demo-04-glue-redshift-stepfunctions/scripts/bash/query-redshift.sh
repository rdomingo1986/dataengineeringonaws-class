#!/usr/bin/env bash
# =====================================================================
# Lança uma consulta ao Redshift via Data API e mostra o resultado.
# A Data API é assíncrona: executa, espera (polling) e traz o resultado.
#
# Uso:
#   ./query-redshift.sh "SELECT COUNT(*) FROM fact_engagement"
#   ./query-redshift.sh         (sem argumento = contagens padrão)
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="us-east-1"
WG="aws-class-dw-wg"
DB="aws_class_dw"

SQL="${1:-SELECT (SELECT COUNT(*) FROM fact_engagement) AS fatos, (SELECT COUNT(*) FROM dim_student) AS estudantes, (SELECT COUNT(*) FROM dim_course) AS cursos}"

echo ">> Executando: $SQL"
QID="$(aws redshift-data execute-statement --workgroup-name "$WG" --database "$DB" --region "$REGION" --sql "$SQL" --query Id --output text)"
echo "   StatementId: $QID"

# Esperar a que termine
while true; do
  sleep 2
  STATUS="$(aws redshift-data describe-statement --id "$QID" --region "$REGION" --query Status --output text)"
  echo "   Status: $STATUS"
  case "$STATUS" in
    FINISHED) break ;;
    FAILED|ABORTED)
      echo ">> A consulta não terminou bem. Detalhe:"
      aws redshift-data describe-statement --id "$QID" --region "$REGION" --query "Error" --output text
      exit 1 ;;
  esac
done

echo ">> Resultado:"
aws redshift-data get-statement-result --id "$QID" --region "$REGION" --output table
