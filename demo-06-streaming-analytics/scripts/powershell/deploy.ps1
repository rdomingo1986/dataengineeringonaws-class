<#
.SYNOPSIS
  Demo 06 - Implanta Streaming Analytics (Kinesis + Firehose + Lambda + CW).
.DESCRIPTION
  Demo autonoma; nao depende de outras demos. Usa SAM package para a Lambda.
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-streaming-demo -Region us-east-1
#>
param(
    [string]$StackName = "aws-class-streaming-demo",
    [string]$Region    = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId       = (aws sts get-caller-identity --query Account --output text)
$ArtifactsBucket = "aws-class-cfn-artifacts-$AccountId-$Region"

Write-Host ">> Stack:  $StackName"
Write-Host ">> Bucket de artefatos: $ArtifactsBucket"

# Bucket de artefatos para o SAM package (cria se nao existir).
aws s3 mb "s3://$ArtifactsBucket" --region $Region 2>$null

aws cloudformation package --template-file infra/streaming-demo.yaml `
    --s3-bucket $ArtifactsBucket --output-template-file packaged.yaml `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha no package." }

aws cloudformation deploy --template-file packaged.yaml `
    --stack-name $StackName --capabilities CAPABILITY_NAMED_IAM `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao." }

Write-Host ">> Outputs:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
