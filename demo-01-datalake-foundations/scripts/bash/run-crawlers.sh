#!/usr/bin/env bash
# =====================================================================
# Dispara os 3 crawlers do Glue para popular o Data Catalog.
#
# Uso:
#   ./run-crawlers.sh [AWS_REGION]
# =====================================================================
set -euo pipefail

REGION="${1:-${AWS_REGION:-us-east-1}}"
CRAWLERS=(
  "aws-class-crawler-raw"
  "aws-class-crawler-cleaned"
  "aws-class-crawler-curated"
)

for c in "${CRAWLERS[@]}"; do
  echo ">> Iniciando crawler: $c"
  aws glue start-crawler --name "$c" --region "$REGION" \
    || echo "   (pode já estar em execução)"
done

echo ">> Crawlers iniciados. Verifique o estado com:"
for c in "${CRAWLERS[@]}"; do
  echo "   aws glue get-crawler --name $c --region $REGION --query 'Crawler.State'"
done
echo ">> Quando estiverem READY, consulte no Athena (workgroup aws-class-datalake-wg)."
