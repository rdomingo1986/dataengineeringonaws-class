# Runbook — Demo 01: Data Lake Foundations

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

> **Base das demos 02, 04 e 05:** esta demo publica Exports de CloudFormation que
> as outras importam. Implante-a **primeiro** e remova-a **por último**. Veja
> "Dependências e integração".

---

## Convenções e nomes de recursos

| Recurso              | Nome / valor                                            |
|----------------------|---------------------------------------------------------|
| Stack CloudFormation | `aws-class-datalake-demo`                              |
| Bucket do data lake  | `aws-class-datalake-<ACCOUNT_ID>-<REGION>`            |
| Bucket de artefatos  | `aws-class-cfn-artifacts-<ACCOUNT_ID>-<REGION>`       |
| Banco de dados Glue  | `aws_class_datalake`                                  |
| Glue jobs            | `aws-class-raw-to-cleaned`, `aws-class-cleaned-to-curated` |
| Crawlers             | `aws-class-crawler-raw` / `-cleaned` / `-curated`     |
| Workgroup Athena     | `aws-class-datalake-wg`                               |
| Papéis por zona      | `aws-class-raw-data-engineer`, `-cleaned-data-analyst`, `-curated-bi-analyst` |
| Região               | `us-east-1` (ajuste se necessário)                     |

> **Nota sobre shells:** um `.sh` criado no Windows pode ter quebras CRLF e falhar
> no Linux (`$'\r': command not found`). Em Linux/macOS garanta quebras LF; no
> Windows prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

- bash / PowerShell (igual)
  ```
  aws sts get-caller-identity --query Account --output text
  aws --version
  ```

**Checklist:**
- [ ] AWS CLI v2 instalada.
- [ ] Credenciais com permissão para CloudFormation, S3, Glue, IAM, Lambda,
      EventBridge e Athena.
- [ ] Capacidade de criar **named IAM roles** (o deploy usa `CAPABILITY_NAMED_IAM`).

> **Sem dependências de entrada:** a Demo 01 é a raiz da cadeia. Não importa
> recursos de nenhuma outra demo.

---

## 1. Implantar o stack

Cria/atualiza: bucket do data lake, bucket de artefatos, Glue jobs, Lambda
disparadora, crawlers, workgroup Athena e papéis por zona. O `deploy` também
empacota o template (Transform SAM) e habilita o EventBridge no bucket.

- bash
  ```bash
  ./scripts/bash/deploy.sh
  # ou: ./scripts/bash/deploy.sh aws-class-datalake-demo us-east-1
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  # ou: .\scripts\powershell\deploy.ps1 -StackName aws-class-datalake-demo -Region us-east-1
  ```

**Dois pontos onde bash e PowerShell divergem (se executar à mão):**

- Habilitar o EventBridge no bucket (feito à parte porque a Early Validation do
  CloudFormation rejeita `EventBridgeConfiguration: {}` vazio no template):
  - bash
    ```bash
    aws s3api put-bucket-notification-configuration \
      --bucket aws-class-datalake-<ACCOUNT_ID>-us-east-1 \
      --notification-configuration '{"EventBridgeConfiguration":{}}' --region us-east-1
    ```
  - PowerShell
    ```powershell
    aws s3api put-bucket-notification-configuration `
      --bucket aws-class-datalake-<ACCOUNT_ID>-us-east-1 `
      --notification-configuration '{\"EventBridgeConfiguration\":{}}' --region us-east-1
    ```

**Verificação pós-deploy:**
```
aws cloudformation describe-stacks --stack-name aws-class-datalake-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
```
Deve retornar `CREATE_COMPLETE` ou `UPDATE_COMPLETE`.

> **Parâmetro opcional `LakeFormationEnabled`:** deixe em `false` (padrão) para a
> Demo 01 sozinha. Use `true` **somente** se a Demo 02 já registrou o bucket no
> Lake Formation (concede grants de LF ao papel do crawler). Veja o RUNBOOK da
> Demo 02.

---

## 2. Enviar dados de amostra (dispara o pipeline)

Envia os lotes JSON ao prefixo `raw/`. O EventBridge dispara o Glue job 1
(raw→cleaned); ao terminar, dispara o job 2 (cleaned→curated).

- bash
  ```bash
  ./scripts/bash/upload-sample-data.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\upload-sample-data.ps1
  ```

**Verificação (os Glue jobs levam ~1-2 min):**
```
aws s3 ls s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1/cleaned/student-events/ --recursive
aws s3 ls s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1/curated/student-engagement/ --recursive
```

> **Dataset grande (opcional):** os lotes `student-events-batch-*.json` já vêm no
> repositório. Para testar desempenho com volume, gere um dataset maior (não
> versionado) e envie-o ao prefixo `raw/`:
> ```
> python data/generate_large_sample.py -n 200000 -o data/student-events-200k.json
> ```
> O gerador aceita `-n/--num-events`, `-o/--output`, `--seed`, `--dup-pct` e
> `--junk-pct` (veja `python data/generate_large_sample.py --help`).

---

## 3. Rodar os crawlers (popular o catálogo)

Depois que `curated/` tiver dados, catalogue as três zonas.

- bash
  ```bash
  ./scripts/bash/run-crawlers.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\run-crawlers.ps1
  ```

**Verificação (aguarde `READY`):**
```
aws glue get-crawler --name aws-class-crawler-curated --region us-east-1 --query "Crawler.State" --output text
```

---

## 4. Consultar no Athena

No console do Athena (workgroup `aws-class-datalake-wg`, banco
`aws_class_datalake`) execute as consultas de `sql/`, zona por zona:
`00-setup.sql`, `10-raw-queries.sql`, `20-cleaned-queries.sql`,
`30-curated-queries.sql`.

Para demonstrar os papéis por zona (IAM puro), use **switch role** no console
para `aws-class-raw-data-engineer`, `-cleaned-data-analyst` e
`-curated-bi-analyst`. Detalhes em [`GUION-DEMO.md`](GUION-DEMO.md).

---

## 5. Teardown (remover tudo)

> **ORDEM CRÍTICA ENTRE DEMOS:** se as Demos 02/04/05 estiverem implantadas,
> remova-as **antes** da Demo 01 (elas importam Exports desta). A exclusão da
> Demo 01 falha enquanto houver um stack importando seus Exports.
> Além disso, se a Demo 02 registrou o bucket no Lake Formation, faça o
> teardown da Demo 02 primeiro (ela desregistra a location).

1. Esvaziar os buckets (o CloudFormation não apaga buckets com objetos):
   ```
   aws s3 rm s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1 --recursive
   aws s3 rm s3://aws-class-athena-results-<ACCOUNT_ID>-us-east-1 --recursive
   ```
2. Apagar o stack:
   ```
   aws cloudformation delete-stack --stack-name aws-class-datalake-demo --region us-east-1
   aws cloudformation wait stack-delete-complete --stack-name aws-class-datalake-demo --region us-east-1
   ```

> O bucket de artefatos `aws-class-cfn-artifacts-*` é compartilhado por várias
> demos; **não** o apague no teardown de uma demo individual.

---

## Dependências e integração com outras demos

**Esta demo é a base da cadeia.** Publica estes Exports de CloudFormation, que
as Demos 02, 04 e 05 importam com `Fn::ImportValue`:

| Export                                        | Consumido por        |
|-----------------------------------------------|----------------------|
| `aws-class-datalake-BucketName`              | Demo 04, Demo 05     |
| `aws-class-datalake-BucketArn`               | Demo 02, Demo 05     |
| `aws-class-datalake-GlueDatabase`            | Demo 02, Demo 04, Demo 05 |
| `aws-class-datalake-CuratedTableName`        | Demo 02              |
| `aws-class-datalake-AthenaResultsBucketName` | Demo 02              |
| `aws-class-datalake-AthenaWorkGroup`         | (referência)         |

**Regras de ordem:**
- **Deploy:** Demo 01 primeiro, sempre.
- **Teardown:** Demo 01 por último (depois de 02, 04 e 05).
- **Evento compartilhado:** o fim do job `aws-class-cleaned-to-curated`
  (estado `SUCCEEDED`) é o gatilho das State Machines das Demos 04 e 05. Se elas
  estiverem implantadas, enviar dados a `raw/` aqui dispara também aquelas
  ramificações em paralelo.
