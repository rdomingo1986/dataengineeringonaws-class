<#
.SYNOPSIS
  Implanta a Demo 02 (Lake Formation access control).
.DESCRIPTION
  Requer: AWS CLI configurado e a Demo 01 ja implantada (exports).
  Se voce nao passar -DeployerArn, usa-se o ARN do caller atual (sts).
.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 -StackName aws-class-lakeformation-demo -Region us-east-1 -DeployerArn arn:aws:iam::<ACCOUNT_ID>:user/<SEU_USUARIO>
#>
param(
    [string]$StackName   = "aws-class-lakeformation-demo",
    [string]$Region      = "us-east-1",
    [string]$DeployerArn = ""
)

$ErrorActionPreference = "Stop"
$env:AWS_PAGER = ""

# Raiz da demo (os scripts vivem em scripts/powershell/)
Set-Location (Join-Path $PSScriptRoot "..\..")

if ([string]::IsNullOrEmpty($DeployerArn)) {
    Write-Host ">> Obtendo o ARN do caller atual..."
    $DeployerArn = (aws sts get-caller-identity --query Arn --output text)
}

Write-Host ">> Stack:    $StackName"
Write-Host ">> Region:   $Region"
Write-Host ">> Deployer: $DeployerArn"

aws cloudformation deploy `
    --template-file infra/lakeformation-demo.yaml `
    --stack-name $StackName `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --parameter-overrides "DeployerPrincipalArn=$DeployerArn"
if ($LASTEXITCODE -ne 0) { throw "Falha na implantacao." }

Write-Host ">> Outputs do stack:"
aws cloudformation describe-stacks --stack-name $StackName `
    --region $Region --query "Stacks[0].Outputs" --output table
