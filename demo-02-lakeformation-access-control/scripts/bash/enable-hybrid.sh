#!/usr/bin/env bash
# =====================================================================
# Coloca a data location do data lake em modo HIBRIDO.
# Coexistem IAM+S3 (Demo 01) e Lake Formation (Demo 02).
# É feito com deregister + register porque update-resource não suporta
# locations com service-linked role.
#
# Uso: ./enable-hybrid.sh [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
REGION="${1:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET_ARN="arn:aws:s3:::aws-class-datalake-${ACCOUNT_ID}-${REGION}"

echo ">> Desregistrando a location..."
aws lakeformation deregister-resource --resource-arn "$BUCKET_ARN" --region "$REGION"

echo ">> Registrando de novo em modo HIBRIDO..."
aws lakeformation register-resource --resource-arn "$BUCKET_ARN" \
  --use-service-linked-role --hybrid-access-enabled --region "$REGION"

echo ">> Estado atual:"
aws lakeformation describe-resource --resource-arn "$BUCKET_ARN" --region "$REGION" \
  --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
echo ">> Pronto. A Demo 01 (IAM) e a Demo 02 (LF) convivem. Dê alguns segundos de propagação."
