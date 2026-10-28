#!/usr/bin/env bash
# =====================================================================
# Implanta o stack da Demo 01 (data lake da plataforma de cursos online).
# Arquitetura: S3 -> EventBridge -> Glue jobs (PySpark) -> S3.
# Requer: AWS CLI configurado.
#
# Fluxo:
#   1) cria o bucket de artefatos (se não existir)
#   2) envia os scripts PySpark de src/glue/ para esse bucket
#   3) empacota o template (por causa do custom resource PrefixInit, que é SAM)
#   4) implanta passando ScriptsBucket
#
# Uso:
#   ./deploy.sh [STACK_NAME] [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-datalake-demo}"
REGION="${2:-us-east-1}"
TEMPLATE="infra/datalake-demo.yaml"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ARTIFACTS_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"

echo ">> Stack:            $STACK_NAME"
echo ">> Region:           $REGION"
echo ">> Artifacts/Scripts bucket: $ARTIFACTS_BUCKET"

# 1) bucket de artefatos (também hospeda os scripts do Glue)
aws s3 mb "s3://${ARTIFACTS_BUCKET}" --region "$REGION" 2>/dev/null || true

# 2) enviar os scripts PySpark do Glue
echo ">> Enviando scripts PySpark para s3://${ARTIFACTS_BUCKET}/src/glue/"
aws s3 cp src/glue/raw_to_cleaned.py "s3://${ARTIFACTS_BUCKET}/src/glue/raw_to_cleaned.py" --region "$REGION"
aws s3 cp src/glue/cleaned_to_curated.py "s3://${ARTIFACTS_BUCKET}/src/glue/cleaned_to_curated.py" --region "$REGION"

# 3) empacotar (o custom resource PrefixInit usa o Transform SAM)
aws cloudformation package --template-file "$TEMPLATE" \
  --s3-bucket "$ARTIFACTS_BUCKET" --output-template-file packaged.yaml \
  --region "$REGION"

# 4) implantar
aws cloudformation deploy --template-file packaged.yaml \
  --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameter-overrides "ScriptsBucket=${ARTIFACTS_BUCKET}"

# 5) habilitar o EventBridge no bucket (à parte: a Early Validation do
#    CloudFormation rejeita EventBridgeConfiguration: {} vazio no template).
DATA_BUCKET="aws-class-datalake-${ACCOUNT_ID}-${REGION}"
echo ">> Habilitando EventBridge em s3://${DATA_BUCKET}"
aws s3api put-bucket-notification-configuration \
  --bucket "$DATA_BUCKET" \
  --notification-configuration '{"EventBridgeConfiguration":{}}' \
  --region "$REGION"

echo ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
