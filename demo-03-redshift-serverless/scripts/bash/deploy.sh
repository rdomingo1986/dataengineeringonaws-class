#!/usr/bin/env bash
# =====================================================================
# Implanta a Demo 03 - Redshift Serverless (fundamentos).
#   1) cria o secret com a senha de admin (se não existir)
#   2) implanta o stack (namespace + workgroup + papel COPY)
#
# Uso: ./deploy.sh [STACK_NAME] [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-redshift-serverless-demo}"
REGION="${2:-us-east-1}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DATA_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"

echo ">> Stack:  $STACK_NAME"
echo ">> Region: $REGION"
echo ">> Bucket de dados: $DATA_BUCKET"

# Bucket de dados (reutiliza o de artefatos; cria se não existir)
aws s3 mb "s3://${DATA_BUCKET}" --region "$REGION" 2>/dev/null || true

# 1) Secret com a senha de admin (atende à política do Redshift)
aws secretsmanager create-secret --name aws-class-rs-admin \
  --secret-string '{"password":"AwsClassDemo2026"}' --region "$REGION" 2>/dev/null \
  || echo ">> O secret aws-class-rs-admin já existe, mantido."

# 2) Implantar
aws cloudformation deploy --template-file infra/redshift-serverless.yaml \
  --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameter-overrides "DataBucket=${DATA_BUCKET}"

echo ">> Outputs:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
