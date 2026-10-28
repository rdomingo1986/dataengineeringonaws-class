#!/usr/bin/env bash
# =====================================================================
# Implanta a Demo 02 (Lake Formation access control).
# Requer: AWS CLI configurado e a Demo 01 já implantada (exports).
#
# Uso:
#   ./deploy.sh [STACK_NAME] [AWS_REGION] [DEPLOYER_ARN]
# Se você não passar DEPLOYER_ARN, usa-se o ARN do caller atual (sts).
# =====================================================================
set -euo pipefail
export AWS_PAGER=""

STACK_NAME="${1:-aws-class-lakeformation-demo}"
REGION="${2:-us-east-1}"
DEPLOYER_ARN="${3:-}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

if [ -z "$DEPLOYER_ARN" ]; then
  echo ">> Obtendo o ARN do caller atual..."
  DEPLOYER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
fi

echo ">> Stack:    $STACK_NAME"
echo ">> Region:   $REGION"
echo ">> Deployer: $DEPLOYER_ARN"

aws cloudformation deploy \
  --template-file infra/lakeformation-demo.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --parameter-overrides "DeployerPrincipalArn=$DEPLOYER_ARN"

echo ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --region "$REGION" --query "Stacks[0].Outputs" --output table
