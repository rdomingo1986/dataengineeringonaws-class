<#
.SYNOPSIS
  Mostra qual identidade/papel voce esta usando agora.
.DESCRIPTION
  Util durante a demo para confirmar o switch role antes de consultar.
.EXAMPLE
  .\whoami.ps1
#>
$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
aws sts get-caller-identity --output table
