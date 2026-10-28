# Runbook — Demo 05: EMR Serverless + Parquet + Step Functions

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

> **Depende das Demos 01 e 02.** Importa Exports da Demo 01 e, como a Demo 02
> registra o bucket no Lake Formation, o crawler precisa de grants de LF. Veja
> "Dependências e integração".

---

## Convenções e nomes de recursos

| Recurso              | Nome / valor                                            |
|----------------------|---------------------------------------------------------|
| Stack CloudFormation | `aws-class-emr-parquet-demo`                           |
| App EMR Serverless   | `aws-class-parquet-app`                               |
| State Machine        | `aws-class-emr-parquet-pipeline`                      |
| Crawler              | `aws-class-crawler-parquet`                           |
| Papel do crawler     | `aws-class-parquet-crawler-role`                      |
| Tabela resultante    | `parquet_student_engagement_parquet` (prefixo `parquet_`) |
| Saída Parquet        | `s3://aws-class-datalake-<ACCOUNT_ID>-<REGION>/analytics/student-engagement-parquet/` |
| Região               | `us-east-1` (ajuste se necessário)                     |

> **Nota sobre shells:** um `.sh` criado no Windows pode ter quebras CRLF e falhar
> no Linux. Em Linux/macOS garanta quebras LF; no Windows prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

1. **Demo 01 implantada** e com dados em `curated/`.
2. **Demo 02 implantada** (bucket registrado no Lake Formation) — necessário para
   que os grants de LF do crawler façam sentido:
   ```
   aws cloudformation describe-stacks --stack-name aws-class-lakeformation-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
   ```
3. **Você é Data Lake Administrator** no Lake Formation (o template cria
   `AWS::LakeFormation::PrincipalPermissions` para o papel do crawler; só um admin
   pode conceder esses grants). Se implantou a Demo 02 com seu ARN em
   `DeployerPrincipalArn`, você já é admin.

**Checklist:**
- [ ] AWS CLI v2; credenciais para CloudFormation, EMR Serverless, Glue, Step
      Functions, Lake Formation, IAM e S3.
- [ ] Capacidade de criar named IAM roles (`CAPABILITY_NAMED_IAM`).

---

## 1. Implantar o stack

Envia o script PySpark do EMR e implanta a aplicação EMR Serverless, o crawler
Parquet (com grants de LF), a State Machine e a regra EventBridge.

- bash
  ```bash
  ./scripts/bash/deploy.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  ```

> **Se o deploy falhar ao criar os grants de LF** (`PrincipalPermissions`), quase
> sempre é porque quem implanta **não é Data Lake Administrator**. Torne-se admin
> no console do Lake Formation (ou via Demo 02) e repita.

**Verificação:**
```
aws cloudformation describe-stacks --stack-name aws-class-emr-parquet-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
```

---

## 2. Executar a ramificação Parquet — dois caminhos

### Caminho A — automático (via evento da Demo 01)
A State Machine dispara quando o job `aws-class-cleaned-to-curated` da Demo 01
termina com `SUCCEEDED` (mesmo gatilho da Demo 04; rodam em paralelo). Reenvie
dados a `raw/` na Demo 01.

### Caminho B — manual (para testar sem reexecutar o data lake)
- bash
  ```bash
  ./scripts/bash/run-pipeline.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\run-pipeline.ps1
  ```

Acompanhe no console do Step Functions: `RunEmrJob` (Spark, espera) →
`StartCrawler` → polling até `READY` → `Success`.

---

## 3. Verificar a tabela Parquet e comparar no Athena

```
aws glue get-crawler --name aws-class-crawler-parquet --region us-east-1 --query "Crawler.State" --output text
```
No Athena (`SHOW TABLES IN aws_class_datalake;`) deve aparecer
`parquet_student_engagement_parquet`. Execute as consultas de
`sql/comparacao-json-vs-parquet.sql`, cada uma sobre a tabela JSON e sobre a
Parquet, e compare **Run time** e **Data scanned** no console do Athena.

---

## 4. Teardown (remover tudo)

> **ORDEM:** remova esta Demo 05 **antes** da Demo 02 e da Demo 01.

1. Esvaziar a saída Parquet (senão a tabela aponta para objetos órfãos):
   ```
   aws s3 rm s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1/analytics/student-engagement-parquet/ --recursive
   ```
2. Apagar o stack:
   ```
   aws cloudformation delete-stack --stack-name aws-class-emr-parquet-demo --region us-east-1
   aws cloudformation wait stack-delete-complete --stack-name aws-class-emr-parquet-demo --region us-east-1
   ```
3. (Opcional) Apagar a tabela catalogada, se o delete do stack não a remover:
   ```
   aws glue delete-table --database-name aws_class_datalake --name parquet_student_engagement_parquet --region us-east-1
   ```

---

## Dependências e integração com outras demos

**Importa da Demo 01** (via `Fn::ImportValue`):

| Export importado                   | Uso nesta demo                           |
|------------------------------------|------------------------------------------|
| `aws-class-datalake-BucketName`   | ler `curated/` e escrever o Parquet      |
| `aws-class-datalake-BucketArn`    | grant de DATA_LOCATION_ACCESS ao crawler |
| `aws-class-datalake-GlueDatabase` | banco onde o crawler cria a tabela       |

**Depende da Demo 02 (Lake Formation):** o bucket está registrado como data
location, então o crawler precisa de grants de LF (`DATA_LOCATION_ACCESS`,
`CREATE_TABLE`). Esses grants são criados pelo template desta demo e exigem que
quem implanta seja **Data Lake Administrator**.

**Gatilho compartilhado com a Demo 04:** mesma regra de evento (fim do job
cleaned→curated). Implantadas juntas, rodam em paralelo (Redshift + Parquet),
independentes.

**Regras de ordem:**
- **Deploy:** Demo 01 → Demo 02 → Demo 05.
- **Teardown:** Demo 05 → Demo 02 → Demo 01.

**Não publica Exports.**
