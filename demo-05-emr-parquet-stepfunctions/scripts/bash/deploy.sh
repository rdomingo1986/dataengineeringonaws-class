#!/usr/bin/env bash
# =====================================================================
# Demo 05 - Implanta EMR Serverless + Parquet + Step Functions.
#   1) envia o script PySpark do EMR ao S3
#   2) implanta o stack (EMR app, crawler, State Machine, regra EventBridge)
# Requer: Demo 01 implantada (exports) e Demo 02 (bucket registrado no LF).
#
# Uso: ./deploy.sh [STACK_NAME] [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-emr-parquet-demo}"
REGION="${2:-us-east-1}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ARTIFACTS_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"

echo ">> Stack:  $STACK_NAME"
echo ">> Bucket de scripts: $ARTIFACTS_BUCKET"

echo ">> Enviando o script PySpark do EMR..."
aws s3 cp src/emr/curated_json_to_parquet.py \
  "s3://${ARTIFACTS_BUCKET}/src/emr/curated_json_to_parquet.py" --region "$REGION"

aws cloudformation deploy --template-file infra/emr-parquet-demo.yaml \
  --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" --parameter-overrides "ScriptsBucket=${ARTIFACTS_BUCKET}"

echo ">> Outputs:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
