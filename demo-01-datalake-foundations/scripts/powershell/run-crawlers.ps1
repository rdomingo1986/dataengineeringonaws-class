<#
.SYNOPSIS
  Dispara os 3 crawlers do Glue para popular o Data Catalog.
.EXAMPLE
  .\run-crawlers.ps1
  .\run-crawlers.ps1 -Region us-east-1
#>
param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

$Crawlers = @(
    "aws-class-crawler-raw",
    "aws-class-crawler-cleaned",
    "aws-class-crawler-curated"
)

foreach ($c in $Crawlers) {
    Write-Host ">> Iniciando crawler: $c"
    aws glue start-crawler --name $c --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "   (pode ja estar em execucao)" }
}

Write-Host ">> Crawlers iniciados. Verifique o estado com:"
foreach ($c in $Crawlers) {
    Write-Host "   aws glue get-crawler --name $c --region $Region --query 'Crawler.State'"
}
Write-Host ">> Quando estiverem READY, consulte no Athena (workgroup aws-class-datalake-wg)."
