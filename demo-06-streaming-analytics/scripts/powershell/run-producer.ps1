<#
.SYNOPSIS
  Demo 06 - Inicia o produtor que simula o stream de eventos.
.DESCRIPTION
  Envia eventos ao Kinesis de forma continua (Ctrl+C para parar).
  Enquanto roda, abra o dashboard do CloudWatch para ver as metricas.
.EXAMPLE
  .\run-producer.ps1 10 300   # 10 eventos/seg durante 5 min
  .\run-producer.ps1          # 5 eventos/seg, infinito
#>
param(
    [double]$Rate    = 5,
    [int]$Seconds    = 0,
    [string]$Region  = "us-east-1"
)

$ErrorActionPreference = "Stop"

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

python src/producer/produce_events.py --stream aws-class-events-stream `
    --region $Region --rate $Rate --seconds $Seconds
