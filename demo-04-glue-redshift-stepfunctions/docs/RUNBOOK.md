# Runbook — Demo 04: Glue + Redshift + Step Functions

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

> **Depende da Demo 01.** Importa Exports do data lake e lê a zona `curated/`.
> Implante a Demo 01 **antes** e garanta que `curated/` tem dados.

---

## Convenções e nomes de recursos

| Recurso              | Nome / valor                                            |
|----------------------|---------------------------------------------------------|
| Stack CloudFormation | `aws-class-redshift-demo`                              |
| Namespace / Workgroup| `aws-class-dw-ns` / `aws-class-dw-wg`                 |
| Banco de dados       | `aws_class_dw`                                             |
| Glue job             | `aws-class-curated-to-dimensional`                    |
| State Machine        | `aws-class-redshift-pipeline`                         |
| Papel de COPY        | `aws-class-redshift-copy-role`                        |
| Secret (senha admin) | `aws-class-redshift-admin`                            |
| Tabelas (estrela)    | `dim_student`, `dim_course`, `fact_engagement`         |
| Região               | `us-east-1` (ajuste se necessário)                     |

> **Nota sobre shells:** um `.sh` criado no Windows pode ter quebras CRLF e falhar
> no Linux. Em Linux/macOS garanta quebras LF; no Windows prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

1. **Demo 01 implantada** e com dados em `curated/`:
   ```
   aws cloudformation describe-stacks --stack-name aws-class-datalake-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
   aws s3 ls s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1/curated/student-engagement/ --recursive
   ```
2. Exports do data lake disponíveis (`aws-class-datalake-BucketName`,
   `-GlueDatabase`):
   ```
   aws cloudformation list-exports --region us-east-1 --query "Exports[?starts_with(Name, 'aws-class-datalake-')].Name" --output text
   ```

**Checklist:**
- [ ] AWS CLI v2; credenciais para CloudFormation, Redshift Serverless, Glue,
      Step Functions, IAM, Secrets Manager e S3.
- [ ] Capacidade de criar named IAM roles (`CAPABILITY_NAMED_IAM`).

---

## 1. Implantar o stack

Cria o secret da senha, envia o script PySpark do Glue e implanta o stack
(Redshift Serverless + Glue job + State Machine + regra EventBridge).

- bash
  ```bash
  ./scripts/bash/deploy.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  ```

> **Divergência de shell (secret):** o JSON inline do secret escreve-se diferente:
> bash `'{"password":"..."}'` · PowerShell `'{\"password\":\"...\"}'`.

**Verificação:**
```
aws cloudformation describe-stacks --stack-name aws-class-redshift-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
```

---

## 2. Carregar o modelo estrela — dois caminhos

### Caminho A — automático (via evento da Demo 01)
A State Machine `aws-class-redshift-pipeline` dispara sozinha quando o job
`aws-class-cleaned-to-curated` da Demo 01 termina com `SUCCEEDED`. Ou seja: ao
(re)enviar dados a `raw/` na Demo 01, esta ramificação roda em paralelo.
Acompanhe no console do Step Functions.

### Caminho B — manual (FASE 1, sem depender do evento)
Roda o Glue job, cria o schema e faz o COPY, com uma pausa para aguardar o job.

- bash
  ```bash
  ./scripts/bash/load-redshift.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\load-redshift.ps1
  ```

---

## 3. Consultar o modelo estrela

Sem argumento mostra contagens (fatos, estudantes, cursos).

- bash
  ```bash
  ./scripts/bash/query-redshift.sh
  ./scripts/bash/query-redshift.sh "SELECT course_name, COUNT(*) FROM fact_engagement f JOIN dim_course c ON f.course_id=c.course_id GROUP BY course_name"
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\query-redshift.ps1
  .\scripts\powershell\query-redshift.ps1 "SELECT course_name, COUNT(*) FROM fact_engagement f JOIN dim_course c ON f.course_id=c.course_id GROUP BY course_name"
  ```

> A variante PowerShell usa `scripts/_format_result.py` para formatar a saída
> (requer Python 3). A variante bash imprime colunas e linhas direto da CLI.

As consultas de negócio estão em `sql/10-analytics-queries.sql`.

---

## 4. Teardown (remover tudo)

> **ORDEM:** remova esta Demo 04 **antes** da Demo 01 (importa Exports dela).

1. Apagar o stack:
   ```
   aws cloudformation delete-stack --stack-name aws-class-redshift-demo --region us-east-1
   aws cloudformation wait stack-delete-complete --stack-name aws-class-redshift-demo --region us-east-1
   ```
2. Apagar o secret:
   ```
   aws secretsmanager delete-secret --secret-id aws-class-redshift-admin --force-delete-without-recovery --region us-east-1
   ```
3. (Opcional) Limpar o staging S3 que o Glue job escreveu:
   ```
   aws s3 rm s3://aws-class-datalake-<ACCOUNT_ID>-us-east-1/stage/redshift/ --recursive
   ```

---

## Dependências e integração com outras demos

**Importa da Demo 01** (via `Fn::ImportValue`):

| Export importado                   | Uso nesta demo                           |
|------------------------------------|------------------------------------------|
| `aws-class-datalake-BucketName`   | ler `curated/` e escrever o staging      |
| `aws-class-datalake-GlueDatabase` | (contexto do catálogo)                   |

**Gatilho compartilhado com a Demo 05:** ambas escutam o mesmo evento (fim do
job `aws-class-cleaned-to-curated`). Se as duas estiverem implantadas, um envio
de dados a `raw/` na Demo 01 dispara as duas ramificações em paralelo (Redshift
e Parquet), de forma independente.

**Publica Exports** (consumidos por nenhuma demo atual, disponíveis para extensão):
`aws-class-redshift-WorkgroupName`, `-Database`, `-CopyRoleArn`,
`-DimensionalJob`.

**Regras de ordem:**
- **Deploy:** Demo 01 → Demo 04.
- **Teardown:** Demo 04 → Demo 01.
