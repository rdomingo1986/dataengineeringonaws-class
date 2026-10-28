# Demo 03 — Redshift Serverless (fundamentos)

Curso: **Data Engineering on AWS** · Domínio de exemplo: plataforma de cursos online

Demo **autônoma** e independente do data lake e da demo de Step Functions.
Ensina os fundamentos do **Amazon Redshift Serverless** e como operar sobre ele
com a **Redshift Data API** (sem conexões JDBC nem VPC):

1. Criar um Redshift Serverless com CloudFormation (namespace + workgroup).
2. Criar uma tabela com a Data API.
3. Carregar dados com `COPY` a partir do S3 com a Data API.
4. Executar consultas com a Data API.

> Não compartilha recursos com as outras demos: usa seu próprio namespace
> (`aws-class-rs-ns`), workgroup (`aws-class-rs-wg`) e banco (`aws_class_demo`).

---

## Cenário

Dados de **matrículas de cursos** da plataforma de cursos online: quem se matriculou, em qual curso,
região, data, status (concluído/em andamento/cancelado) e preço. Um caso típico de
data warehouse para analítica de negócio (receita, conclusão, cancelamentos).

Tabela `enrollments`:

| coluna         | tipo          |
|----------------|---------------|
| enrollment_id  | INTEGER (PK)  |
| student_name   | VARCHAR(256)  |
| course         | VARCHAR(128)  |
| region         | VARCHAR(16)   |
| enrolled_at    | DATE (SORTKEY)|
| status         | VARCHAR(16)   |
| price          | DECIMAL(10,2) |

---

## Estrutura

```
demo-03-redshift-serverless/
├── README.md
├── docs/
│   └── RUNBOOK.md                 Guia operacional passo a passo (bash + PowerShell)
├── infra/
│   └── redshift-serverless.yaml   CloudFormation: namespace + workgroup + papel COPY
├── data/
│   └── enrollments.csv            30 matrículas de exemplo
├── sql/
│   └── queries.sql                Consultas de negócio de exemplo
└── scripts/
    ├── bash/                      Scripts .sh (Linux/macOS/Git Bash)
    │   ├── deploy.sh              Cria o secret + implanta o stack
    │   ├── 01-create-table.sh     Cria a tabela via Data API
    │   ├── 02-load-data.sh        Envia o CSV ao S3 + COPY via Data API
    │   └── 03-query.sh            Executa consultas via Data API
    ├── powershell/                Scripts .ps1 (Windows)
    │   ├── deploy.ps1
    │   ├── 01-create-table.ps1
    │   ├── 02-load-data.ps1
    │   └── 03-query.ps1
    └── _format_result.py          Formatador opcional do resultado da Data API
```

---

## Guia da demo

> O passo a passo completo — com verificações prévias, comandos em **bash** e
> **PowerShell** lado a lado, e o teardown — está em **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**.
> Abaixo, o resumo.

### 1. Implantar o Redshift Serverless
```bash
./scripts/bash/deploy.sh          # Linux/macOS/Git Bash
```
```powershell
.\scripts\powershell\deploy.ps1   # Windows
```
Cria o secret de admin, o namespace, o workgroup (8 RPU, mínimo) e o papel de
COPY. Leva ~3-5 min.

### 2. Criar a tabela (Data API)
```bash
./scripts/bash/01-create-table.sh
```
```powershell
.\scripts\powershell\01-create-table.ps1
```
Mostra como executar DDL sem conexão JDBC: a Data API roda o `CREATE TABLE`
de forma assíncrona e o script espera até terminar.

### 3. Carregar dados (Data API + COPY)
```bash
./scripts/bash/02-load-data.sh
```
```powershell
.\scripts\powershell\02-load-data.ps1
```
Envia `enrollments.csv` ao S3 e executa `COPY` — a forma canônica e eficiente de
carregar o Redshift a partir do S3.

### 4. Consultar (Data API)
```bash
./scripts/bash/03-query.sh
./scripts/bash/03-query.sh "SELECT region, COUNT(*) FROM enrollments GROUP BY region"
```
```powershell
.\scripts\powershell\03-query.ps1
.\scripts\powershell\03-query.ps1 "SELECT region, COUNT(*) FROM enrollments GROUP BY region"
```
Sem argumento, usa uma consulta de exemplo (matrículas e receita por curso).
As consultas de `sql/queries.sql` podem ser passadas como argumento ou usadas no
Query Editor v2.

---

## Conceitos do módulo que esta demo cobre

- **Redshift Serverless**: você não gerencia nós; define capacidade base (RPU) e
  paga por uso; pausa automaticamente quando não há atividade.
- **Redshift Data API**: executa SQL sem manter conexões JDBC/ODBC nem estar na
  VPC. Assíncrona (executar → consultar status → trazer resultado). Ideal para
  automação e para scripts/Lambdas.
- **COPY a partir do S3**: o método canônico de ingestão em massa no Redshift.
- **DISTSTYLE / SORTKEY**: a tabela usa `DISTSTYLE AUTO` e `SORTKEY(enrolled_at)`
  para otimizar consultas temporais.

> Custo: o Redshift Serverless cobra por RPU-hora com um mínimo; pausa
> automaticamente quando não há consultas. Para não deixar custo, apague o stack ao
> terminar (ver teardown geral do curso).
