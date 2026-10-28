# Runbook — Demo 03: Redshift Serverless (fundamentos)

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

---

## Convenções e nomes de recursos

| Recurso            | Nome / valor                                  |
|--------------------|-----------------------------------------------|
| Stack CloudFormation | `aws-class-redshift-serverless-demo`       |
| Namespace Redshift | `aws-class-rs-ns`                            |
| Workgroup          | `aws-class-rs-wg`                            |
| Banco de dados     | `aws_class_demo`                                |
| Papel de COPY      | `aws-class-rs-copy-role`                    |
| Secret (senha admin) | `aws-class-rs-admin`                       |
| Tabela             | `enrollments`                                |
| Região             | `us-east-1` (ajuste se necessário)           |

> **Nota sobre shells:** um arquivo `.sh` criado no Windows pode ter quebras de
> linha CRLF e falhar no Linux (`$'\r': command not found`). Se for executar os
> `.sh` em Linux/macOS, garanta quebras LF. No Windows, prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

**Verificar que a AWS CLI está configurada e você está na conta certa:**

- bash
  ```bash
  aws sts get-caller-identity --query Account --output text
  ```
- PowerShell
  ```powershell
  aws sts get-caller-identity --query Account --output text
  ```

**Checklist:**
- [ ] AWS CLI v2 instalada (`aws --version`).
- [ ] Credenciais com permissão para CloudFormation, Redshift Serverless, IAM,
      Secrets Manager e S3.
- [ ] Python 3 disponível (apenas se for usar o formatador de resultados opcional
      `scripts/_format_result.py`).

> **Demo autônoma:** esta demo **não** depende de nenhuma outra. Não importa nem
> exporta recursos. Veja "Dependências e integração" no final.

---

## 1. Implantar o stack

Cria o secret da senha de admin (se não existir), o namespace, o workgroup
(8 RPU, mínimo) e o papel de COPY. Leva ~3-5 min.

- bash
  ```bash
  ./scripts/bash/deploy.sh
  # ou com nome de stack / região explícitos:
  ./scripts/bash/deploy.sh aws-class-redshift-serverless-demo us-east-1
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  # ou:
  .\scripts\powershell\deploy.ps1 -StackName aws-class-redshift-serverless-demo -Region us-east-1
  ```

**O que o passo faz internamente (se preferir executar à mão):**

1. Garante o bucket de artefatos (reutiliza o da conta):
   - bash
     ```bash
     ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
     aws s3 mb "s3://aws-class-cfn-artifacts-${ACCOUNT_ID}-us-east-1" --region us-east-1
     ```
   - PowerShell
     ```powershell
     $AccountId = (aws sts get-caller-identity --query Account --output text)
     aws s3 mb "s3://aws-class-cfn-artifacts-$AccountId-us-east-1" --region us-east-1
     ```
2. Cria o secret com a senha de admin (a sintaxe do JSON muda por shell — este é
   o ponto onde bash e PowerShell mais divergem):
   - bash
     ```bash
     aws secretsmanager create-secret --name aws-class-rs-admin \
       --secret-string '{"password":"AwsClassDemo2026"}' --region us-east-1
     ```
   - PowerShell
     ```powershell
     aws secretsmanager create-secret --name aws-class-rs-admin `
       --secret-string '{\"password\":\"AwsClassDemo2026\"}' --region us-east-1
     ```
3. Implanta o template:
   - bash
     ```bash
     aws cloudformation deploy --template-file infra/redshift-serverless.yaml \
       --stack-name aws-class-redshift-serverless-demo \
       --capabilities CAPABILITY_NAMED_IAM --region us-east-1 \
       --parameter-overrides "DataBucket=aws-class-cfn-artifacts-${ACCOUNT_ID}-us-east-1"
     ```
   - PowerShell
     ```powershell
     aws cloudformation deploy --template-file infra/redshift-serverless.yaml `
       --stack-name aws-class-redshift-serverless-demo `
       --capabilities CAPABILITY_NAMED_IAM --region us-east-1 `
       --parameter-overrides "DataBucket=aws-class-cfn-artifacts-$AccountId-us-east-1"
     ```

**Verificação pós-deploy:**
- bash / PowerShell (igual)
  ```
  aws cloudformation describe-stacks --stack-name aws-class-redshift-serverless-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
  ```
  Deve retornar `CREATE_COMPLETE` ou `UPDATE_COMPLETE`.

---

## 2. Criar a tabela (Data API)

Executa `CREATE TABLE enrollments` de forma assíncrona e aguarda o término.

- bash
  ```bash
  ./scripts/bash/01-create-table.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\01-create-table.ps1
  ```

---

## 3. Carregar dados (Data API + COPY)

Envia `data/enrollments.csv` ao S3 e executa `COPY`.

- bash
  ```bash
  ./scripts/bash/02-load-data.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\02-load-data.ps1
  ```

---

## 4. Consultar (Data API)

Sem argumento usa uma consulta de exemplo (matrículas e receita por curso).

- bash
  ```bash
  ./scripts/bash/03-query.sh
  ./scripts/bash/03-query.sh "SELECT region, COUNT(*) FROM enrollments GROUP BY region"
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\03-query.ps1
  .\scripts\powershell\03-query.ps1 "SELECT region, COUNT(*) FROM enrollments GROUP BY region"
  ```

As consultas de `sql/queries.sql` também podem ser coladas no Query Editor v2
do console do Redshift.

---

## 5. Teardown (remover tudo)

> **Ordem importa:** primeiro apague o stack (remove namespace, workgroup e
> papel), depois o secret. O secret é removido com janela de recuperação, por
> isso usa-se `--force-delete-without-recovery` para não deixar resíduo.

1. Apagar o stack:
   - bash
     ```bash
     aws cloudformation delete-stack --stack-name aws-class-redshift-serverless-demo --region us-east-1
     aws cloudformation wait stack-delete-complete --stack-name aws-class-redshift-serverless-demo --region us-east-1
     ```
   - PowerShell
     ```powershell
     aws cloudformation delete-stack --stack-name aws-class-redshift-serverless-demo --region us-east-1
     aws cloudformation wait stack-delete-complete --stack-name aws-class-redshift-serverless-demo --region us-east-1
     ```
2. Apagar o secret:
   - bash / PowerShell (igual)
     ```
     aws secretsmanager delete-secret --secret-id aws-class-rs-admin --force-delete-without-recovery --region us-east-1
     ```
3. (Opcional) Remover o CSV enviado ao S3:
   - bash / PowerShell (igual)
     ```
     aws s3 rm s3://aws-class-cfn-artifacts-<ACCOUNT_ID>-us-east-1/demo03/enrollments.csv --region us-east-1
     ```

> O bucket de artefatos é compartilhado com outras demos; **não** o apague aqui.

---

## Dependências e integração com outras demos

- **Entrada:** nenhuma. Esta demo cria seu próprio namespace, workgroup e banco
  (`aws_class_demo`), independentes dos das outras demos.
- **Saída / exports:** nenhuma. Não publica Exports de CloudFormation, então
  nenhuma outra demo depende desta.
- **Conflitos de nome a evitar:** usa o prefixo `aws-class-rs-*`, distinto do
  data warehouse da Demo 04 (`aws-class-dw-*`). As duas podem coexistir na mesma
  conta sem colisão.
- **Bucket compartilhado:** reutiliza o bucket de artefatos
  `aws-class-cfn-artifacts-<ACCOUNT_ID>-<REGION>` apenas para hospedar o CSV de carga.
  No teardown, remova só o objeto `demo03/`, nunca o bucket.
