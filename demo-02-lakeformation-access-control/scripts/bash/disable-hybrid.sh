#!/usr/bin/env bash
# =====================================================================
# Coloca a data location do data lake em modo SÓ LAKE FORMATION.
# Os papéis da Demo 01 (IAM+S3) deixam de poder ler; só os principals
# com grants do Lake Formation acessam os dados.
# É feito com deregister + register (não com CloudFormation).
#
# Uso: ./disable-hybrid.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET_ARN="arn:aws:s3:::aws-class-datalake-${ACCOUNT_ID}-${REGION}"

echo ">> Desregistrando a location..."
aws lakeformation deregister-resource --resource-arn "$BUCKET_ARN" --region "$REGION"

echo ">> Registrando de novo em modo SÓ LAKE FORMATION..."
aws lakeformation register-resource --resource-arn "$BUCKET_ARN" \
  --use-service-linked-role --region "$REGION"

echo ">> Estado atual:"
aws lakeformation describe-resource --resource-arn "$BUCKET_ARN" --region "$REGION" \
  --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
echo ">> Pronto. Só os papéis com grants do Lake Formation podem ler."
