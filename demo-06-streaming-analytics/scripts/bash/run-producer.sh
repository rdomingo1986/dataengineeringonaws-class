#!/usr/bin/env bash
# =====================================================================
# Demo 06 - Inicia o produtor que simula o stream de eventos.
# Envia eventos ao Kinesis de forma contínua (Ctrl+C para parar).
# Enquanto roda, abra o dashboard do CloudWatch para ver as métricas.
#
# Uso: ./run-producer.sh [RATE_EVENTOS_POR_SEG] [SEGUNDOS]
#   ex: ./run-producer.sh 10 300    (10 eventos/seg durante 5 min)
#       ./run-producer.sh           (5 eventos/seg, infinito)
# =====================================================================
set -euo pipefail
REGION="us-east-1"
RATE="${1:-5}"
SECONDS_ARG="${2:-0}"

# Raiz da demo (os scripts vivem em scripts/bash/)
cd "$(dirname "$0")/../.."

python src/producer/produce_events.py --stream aws-class-events-stream \
  --region "$REGION" --rate "$RATE" --seconds "$SECONDS_ARG"
