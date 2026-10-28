#!/usr/bin/env bash
# =====================================================================
# Implanta a Demo 04 (Redshift + modelo dimensional).
# Requer: AWS CLI configurado e a Demo 01 implantada (exports).
#
# Fluxo:
#   1) cria o secret com a senha do Redshift (se não existir)
#   2) envia o script PySpark do Glue
#   3) implanta o stack (Redshift Serverless + Glue job + State Machine)
#
# Uso: ./deploy.sh [STACK_NAME] [AWS_REGION]
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-redshift-demo}"
REGION="${2:-us-east-1}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ARTIFACTS_BUCKET="aws-class-cfn-artifacts-${ACCOUNT_ID}-${REGION}"

echo ">> Stack:   $STACK_NAME"
echo ">> Region:  $REGION"

# 1) Secret com a senha de admin do Redshift (edite se quiser outra).
#    Deve atender à política do Redshift: 8-64 chars, maiúsc, minúsc e número.
aws secretsmanager create-secret --name aws-class-redshift-admin \
  --secret-string '{"password":"AwsClassDemo2026"}' --region "$REGION" 2>/dev/null \
  || echo ">> O secret já existe, mantido."

# 2) Enviar o script PySpark do Glue
echo ">> Enviando o script do Glue..."
aws s3 cp src/glue/curated_to_dimensional.py \
  "s3://${ARTIFACTS_BUCKET}/src/glue/curated_to_dimensional.py" --region "$REGION"

# 3) Implantar o stack
aws cloudformation deploy --template-file infra/redshift-stepfn-demo.yaml \
  --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameter-overrides "ScriptsBucket=${ARTIFACTS_BUCKET}"

echo ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
