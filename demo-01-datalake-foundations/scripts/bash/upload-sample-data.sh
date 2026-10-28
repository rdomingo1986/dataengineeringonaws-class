#!/usr/bin/env bash
# =====================================================================
# Envia os dados de amostra para o prefixo raw/ para disparar o pipeline.
#
# Uso:
#   ./upload-sample-data.sh [BUCKET_NAME]
# Se você não passar o bucket, ele é deduzido do padrão por conta/região.
# =====================================================================
set -euo pipefail

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

REGION="${AWS_REGION:-us-east-1}"
if [ $# -ge 1 ]; then
  BUCKET="$1"
else
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  BUCKET="aws-class-datalake-${ACCOUNT_ID}-${REGION}"
fi

echo ">> Enviando dados de amostra para s3://${BUCKET}/raw/student-events/"

aws s3 cp data/student-events-batch-1.json \
  "s3://${BUCKET}/raw/student-events/2026/03/01/student-events-batch-1.json" \
  --region "$REGION"

aws s3 cp data/student-events-batch-2.json \
  "s3://${BUCKET}/raw/student-events/2026/03/02/student-events-batch-2.json" \
  --region "$REGION"

echo ">> Pronto. O EventBridge deve disparar os Glue jobs pelas notificações de evento."
echo ">> Verifique cleaned/ e curated/ em alguns minutos (os Glue jobs levam ~1-2 min):"
echo "   aws s3 ls s3://${BUCKET}/cleaned/student-events/ --recursive"
echo "   aws s3 ls s3://${BUCKET}/curated/student-engagement/ --recursive"
