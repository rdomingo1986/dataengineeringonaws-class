<#
.SYNOPSIS
  Implanta o stack da Demo 01 (data lake da plataforma de cursos online).
.DESCRIPTION
  Arquitetura: S3 -> EventBridge -> Glue jobs (PySpark) -> S3.
  Fluxo:
    1) cria o bucket de artefatos (se nao existir)
    2) envia os scripts PySpark de src/glue/ para esse bucket
    3) empacota o template (o custom resource PrefixInit usa o Transform SAM)
    4) implanta passando ScriptsBucket
    5) habilita o EventBridge no bucket (a parte, por causa da Early Validation)
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-datalake-demo -Region us-east-1
#>
param(
    [string]$StackName = "aws-class-datalake-demo",
    [string]$Region    = "us-east-1"
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""
$Template = "infra/datalake-demo.yaml"

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

$AccountId       = (aws sts get-caller-identity --query Account --output text)
$ArtifactsBucket = "aws-class-cfn-artifacts-$AccountId-$Region"

Write-Host ">> Stack:            $StackName"
Write-Host ">> Region:           $Region"
Write-Host ">> Artifacts/Scripts bucket: $ArtifactsBucket"

# 1) bucket de artefatos (tambem hospeda os scripts do Glue)
aws s3 mb "s3://$ArtifactsBucket" --region $Region 2>$null

# 2) enviar os scripts PySpark do Glue
Write-Host ">> Enviando scripts PySpark para s3://$ArtifactsBucket/src/glue/"
aws s3 cp src/glue/raw_to_cleaned.py "s3://$ArtifactsBucket/src/glue/raw_to_cleaned.py" --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar raw_to_cleaned.py." }
aws s3 cp src/glue/cleaned_to_curated.py "s3://$ArtifactsBucket/src/glue/cleaned_to_curated.py" --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao enviar cleaned_to_curated.py." }

# 3) empacotar (o custom resource PrefixInit usa o Transform SAM)
aws cloudformation package --template-file $Template `
    --s3-bucket $ArtifactsBucket --output-template-file packaged.yaml `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha no package." }

# 4) implantar
aws cloudformation deploy --template-file packaged.yaml `
    --stack-name $StackName --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --parameter-overrides "ScriptsBucket=$ArtifactsBucket"
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao." }

# 5) habilitar o EventBridge no bucket (a parte: a Early Validation do
#    CloudFormation rejeita EventBridgeConfiguration: {} vazio no template).
$DataBucket = "aws-class-datalake-$AccountId-$Region"
Write-Host ">> Habilitando EventBridge em s3://$DataBucket"
aws s3api put-bucket-notification-configuration `
    --bucket $DataBucket `
    --notification-configuration '{\"EventBridgeConfiguration\":{}}' `
    --region $Region
if ($LASTEXITCODE -ne 0) { throw "Falha ao habilitar o EventBridge." }

Write-Host ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
