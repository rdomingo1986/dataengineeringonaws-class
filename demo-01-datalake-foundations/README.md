# Demo 01 — Data Lake Foundations

Curso: **Data Engineering on AWS** · Domínio de exemplo: plataforma de cursos online

Esta demo mostra a lógica mais básica de um data lake na AWS: ingestão no S3,
catalogação com Glue, transformações encadeadas com **jobs do AWS Glue (PySpark)**
disparadas por **Amazon EventBridge**, e consulta com Athena sobre o Glue Data
Catalog.

O cenário foi desenhado para **conectar-se depois com o Lake Formation (Demo 02)**:
nesta demo o acesso é controlado com IAM puro e o bucket **não** é registrado no
Lake Formation, mas o banco de dados, as tabelas e as colunas sensíveis já ficam
preparados para demonstrar controle de acesso por recurso e por LF-Tags mais adiante.

---

## Cenário de negócio

A plataforma de cursos online opera uma plataforma de aprendizagem online. A plataforma emite eventos
de atividade dos estudantes (logins, lições assistidas, quizzes, tempo de vídeo).
Esses eventos chegam **"sujos"**: datas em formatos mistos, nomes de curso
inconsistentes, maiúsculas/minúsculas desalinhadas, campos nulos, duplicados e
números como texto.

O objetivo do data lake é levar esses dados brutos a um estado **curado e
consultável** para analytics de *engagement* (retenção, conclusão de cursos,
horas de estudo) sem tocar na aplicação de origem.

---

## Arquitetura

```
                  Upload de objeto JSON "sujo"
                              │
                              ▼
        s3://<bucket>/raw/student-events/.../*.json
                              │  (S3 → EventBridge)
                              ▼
                 ┌────────────────────────────────┐
                 │  Lambda disparadora (glue-trigger)  │  Só faz StartJobRun
                 └────────────────────────────────┘
                              │
                              ▼
                 ┌──────────────────────────────┐
                 │  Glue job 1  raw → cleaned    │  Limpeza (PySpark):
                 │                               │  - normaliza datas para ISO-8601
                 │                               │  - normaliza strings / cursos
                 │                               │  - remove nulos e duplicados
                 │                               │  - tipa números
                 └──────────────────────────────┘
                              │
                              ▼
          s3://<bucket>/cleaned/student-events/*.jsonl
                              │  (S3 → EventBridge → Lambda disparadora)
                              ▼
                 ┌──────────────────────────────┐
                 │  Glue job 2  cleaned → curated │  Enriquecimento (PySpark):
                 │                               │  - deriva métricas de engagement
                 │                               │  - particiona por event_date
                 │                               │  - deixa colunas sensíveis (email,
                 │                               │    cpf_hash, region) para o Lake Formation
                 └──────────────────────────────┘
                              │
                              ▼
   s3://<bucket>/curated/student-engagement/event_date=YYYY-MM-DD/*.jsonl
                              │
             ┌────────────────┴─────────────────┐
             ▼                                   ▼
   Glue Crawlers (raw/cleaned/curated)   Glue Data Catalog (DB: aws_class_datalake)
             │                                   │
             └──────────────┬────────────────────┘
                            ▼
                         Athena  → consultas SQL por zona
```

> Observação: o encadeamento usa **EventBridge** porque o S3 não pode invocar um
> Glue job diretamente. Por isso o evento do S3 aciona uma **Lambda disparadora**
> mínima (`glue-trigger`) que apenas chama `StartJobRun` do job correspondente ao
> prefixo. Todo o processamento pesado fica nos **Glue jobs PySpark**.
>
> A versão anterior fazia as transformações com funções Lambda (preservada em
> `legacy/` como referência). Migrou-se para Glue por ser mais representativo de
> pipelines reais de engenharia de dados.

### Componentes

| Serviço AWS          | Papel na demo                                                      |
|----------------------|---------------------------------------------------------------------|
| **S3**               | Armazenamento do data lake com 3 zonas: `raw`, `cleaned`, `curated` |
| **EventBridge**      | Encadeia o processamento: `raw/`→job1, `cleaned/`→job2              |
| **Lambda (trigger)** | Mínima: recebe o evento e faz `StartJobRun` do Glue job            |
| **Glue job 1**       | Limpeza raw → cleaned (PySpark)                                    |
| **Glue job 2**       | Enriquecimento/agregação cleaned → curated (PySpark)              |
| **Glue Data Catalog**| Banco de dados `aws_class_datalake`                              |
| **Glue Crawlers**    | Populam metadados de cada zona (raw/cleaned/curated)              |
| **Athena**           | Consulta SQL sobre o catálogo; workgroup dedicado                 |
| **IAM**              | Controle de acesso na Demo 01 (Lake Formation chega na Demo 02)   |

---

## Papéis IAM por zona (para demonstrar permissões)

Para demonstrar de onde vêm as permissões sem Lake Formation, há **um papel IAM por
zona**, cada um representando um perfil que só pode ler o seu prefixo no S3:

| Papel IAM                          | Zona       | Perfil                    |
|------------------------------------|------------|---------------------------|
| `aws-class-raw-data-engineer`     | `raw/`     | Data Engineer             |
| `aws-class-cleaned-data-analyst`  | `cleaned/` | Data Analyst              |
| `aws-class-curated-bi-analyst`    | `curated/` | BI Analyst / Business     |

Assuma cada papel por **switch role** no console para ver que cada um só acessa a
sua zona. Detalhes no `docs/GUION-DEMO.md`.

---

## Estrutura do repositório

```
demo-01-datalake-foundations/
├── README.md                     Este arquivo
├── docs/
│   ├── RUNBOOK.md                Guia operacional passo a passo (bash + PowerShell)
│   └── GUION-DEMO.md             Roteiro da demonstração ao vivo
├── infra/
│   └── datalake-demo.yaml        Template CloudFormation (todo o stack)
├── src/
│   ├── glue/
│   │   ├── raw_to_cleaned.py     Glue job 1: limpeza (PySpark)
│   │   └── cleaned_to_curated.py Glue job 2: enriquecimento (PySpark)
│   └── trigger/
│       └── handler.py            Lambda disparadora (EventBridge → StartJobRun)
├── legacy/
│   └── lambdas/                  Versão antiga com Lambda (referência, não é deployada)
├── data/
│   ├── student-events-batch-1.json   Dados brutos "sujos" (lote pequeno)
│   ├── student-events-batch-2.json   Segundo lote
│   └── generate_large_sample.py      Gerador parametrizável de dataset (datasets grandes não versionados)
├── sql/
│   ├── 00-setup.sql              Referência e SHOW TABLES
│   ├── 10-raw-queries.sql        Consultas sobre a zona raw
│   ├── 20-cleaned-queries.sql    Consultas sobre a zona cleaned
│   └── 30-curated-queries.sql    Consultas de negócio sobre curated
└── scripts/
    ├── bash/                     Scripts .sh (Linux/macOS/Git Bash)
    │   ├── deploy.sh             Deploy do stack
    │   ├── upload-sample-data.sh Envia os dados de amostra ao prefixo raw
    │   └── run-crawlers.sh       Dispara os crawlers do Glue
    └── powershell/               Scripts .ps1 (Windows)
        ├── deploy.ps1
        ├── upload-sample-data.ps1
        └── run-crawlers.ps1
```

> Há versões `.sh` (Linux/macOS/Git Bash) e `.ps1` (Windows) de cada script.
> O passo a passo operacional completo está em
> **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**.

---

## Roteiro da demo (ordem sugerida ao vivo)

1. **Mostrar o bucket e as 3 zonas** (`raw/`, `cleaned/`, `curated/`).
2. **Enviar** `data/student-events-batch-1.json` ao prefixo `raw/`.
   - Abrir o objeto e mostrar como está "sujo".
3. **Ver o Glue job 1 ser disparado** (via EventBridge + Lambda) e escrever em `cleaned/`.
4. **Ver o Glue job 2 ser disparado** pela escrita em `cleaned/` e escrever em
   `curated/` particionado por `event_date=`.
5. **Rodar os crawlers** (`scripts/powershell/run-crawlers.ps1` ou `scripts/bash/run-crawlers.sh`) para popular o Glue Data Catalog.
6. **Ir ao Athena** e executar as consultas de `sql/` zona por zona.
7. **Demonstrar os papéis por zona** (switch role) e as permissões IAM — ver o
   `docs/GUION-DEMO.md`.

---

## Ponte para a Demo 02 (Lake Formation)

O que esta demo deixa preparado para controle de acesso:

- Um **único banco de dados** do Glue (`aws_class_datalake`) com tabelas por zona
  (`raw_raw`, `cleaned_cleaned`, `curated_curated`).
- A tabela curada inclui **colunas sensíveis** (`student_email`, `cpf_hash`,
  `region`) para demonstrar:
  - **Controle por recurso**: dar acesso a `curated` mas não a `raw`.
  - **Column-level security**: ocultar `student_email` / `cpf_hash`.
  - **Row-level security / LF-Tags**: filtrar por `region` (ex.: só `BR-SP`).
- O bucket **NÃO** é registrado como *data location* no Lake Formation nesta demo.
  Na Demo 02 ele será registrado e o controle migrará de IAM para permissões do
  Lake Formation.

> O nome do bucket padrão segue o padrão `aws-class-datalake-<ACCOUNT_ID>-<REGION>`.
