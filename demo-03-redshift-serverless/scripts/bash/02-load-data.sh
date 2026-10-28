#!/usr/bin/env bash
# =====================================================================
# Demo 03 - Passo 2: carregar dados com COPY a partir do S3 via Data API.
#   1) envia o CSV de amostra ao S3
#   2) executa COPY enrollments FROM 's3://...' com o papel de cópia
#
# Uso: ./02-load-data.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"
WG="aws-class-rs-wg"
DB="aws_class_demo"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DATA_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"
COPY_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/aws-class-rs-copy-role"
S3_KEY="demo03/enrollments.csv"

echo ">> Enviando CSV para s3://${DATA_BUCKET}/${S3_KEY}"
aws s3 cp data/enrollments.csv "s3://${DATA_BUCKET}/${S3_KEY}" --region "$REGION"

SQL="COPY enrollments FROM 's3://${DATA_BUCKET}/${S3_KEY}' IAM_ROLE '${COPY_ROLE}' FORMAT AS CSV;"

echo ">> Executando COPY via Data API..."
QID="$(aws redshift-data execute-statement --workgroup-name "$WG" --database "$DB" \
  --region "$REGION" --sql "$SQL" --query Id --output text)"
echo "   StatementId: $QID"

while true; do
  sleep 2
  STATUS="$(aws redshift-data describe-statement --id "$QID" --region "$REGION" --query Status --output text)"
  echo "   Status: $STATUS"
  case "$STATUS" in
    FINISHED) echo ">> Dados carregados."; break ;;
    FAILED|ABORTED)
      aws redshift-data describe-statement --id "$QID" --region "$REGION" --query "Error" --output text
      exit 1 ;;
  esac
done
