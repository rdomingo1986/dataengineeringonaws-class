#!/usr/bin/env bash
# =====================================================================
# Mostra qual identidade/papel você está usando agora.
# Útil durante a demo para confirmar o switch role antes de consultar.
#
# Uso: ./whoami.sh
# =====================================================================
set -euo pipefail
export AWS_PAGER=""
aws sts get-caller-identity --output table
