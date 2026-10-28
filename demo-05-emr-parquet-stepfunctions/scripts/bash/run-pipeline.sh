#!/usr/bin/env bash
# =====================================================================
# Demo 05 - Dispara manualmente a State Machine da ramificação Parquet.
# (Em produção ela dispara sozinha pelo evento do job cleaned->curated;
#  este script serve para testar/demonstrar sem reexecutar o data lake.)
#
# Uso: ./run-pipeline.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SM_ARN="arn:aws:states:${REGION}:${ACCOUNT_ID}:stateMachine:aws-class-emr-parquet-pipeline"

echo ">> Iniciando a State Machine da ramificação Parquet..."
aws stepfunctions start-execution --state-machine-arn "$SM_ARN" --region "$REGION" \
  --query "executionArn" --output text
echo ">> Acompanhe o progresso no console do Step Functions."
