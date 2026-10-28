#!/usr/bin/env bash
# =====================================================================
# Demo 06 - Implanta Streaming Analytics (Kinesis + Firehose + Lambda + CW).
# Demo autônoma; não depende de outras demos.
#
# Uso: ./deploy.sh [STACK_NAME] [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-streaming-demo}"
REGION="${2:-us-east-1}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ARTIFACTS_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"

echo ">> Stack:  $STACK_NAME"
echo ">> Bucket de artefatos: $ARTIFACTS_BUCKET"

# Bucket de artefatos para o SAM package (cria se não existir).
aws s3 mb "s3://${ARTIFACTS_BUCKET}" --region "$REGION" 2>/dev/null || true

aws cloudformation package --template-file infra/streaming-demo.yaml \
  --s3-bucket "$ARTIFACTS_BUCKET" --output-template-file packaged.yaml \
  --region "$REGION"

aws cloudformation deploy --template-file packaged.yaml \
  --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo ">> Outputs:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
