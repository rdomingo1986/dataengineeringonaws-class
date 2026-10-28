# Demo 04 — Redshift + Step Functions

Curso: **Data Engineering on AWS** · Domínio de exemplo: plataforma de cursos online

Esta demo adiciona uma **segunda ramificação de processamento em paralelo** ao data
lake da [Demo 01](../demo-01-datalake-foundations). Demonstra dois conceitos do
módulo:

1. **A zona `raw` como fonte da verdade com múltiplos consumidores.** A partir dos
   mesmos dados brutos saem duas ramificações independentes, cada uma otimizada para
   sua necessidade de consulta:
   - **Ramificação data lake (já existente):** `raw → cleaned → curated`, disparada
     pelo EventBridge, para analítica exploratória com Athena.
   - **Ramificação data warehouse (esta demo):** `raw → modelo dimensional →
     Redshift`, orquestrada por **Step Functions**, para BI.
2. **Orquestração com Step Functions + carga no Amazon Redshift Serverless.**

```
                         raw/  (dados originais = fonte da verdade)
                           │
         ┌─────────────────┴───────────────────┐
         │ (EventBridge → Lambda → Glue)        │ (EventBridge → Step Functions)
         ▼                                      ▼
   Ramificação DATA LAKE                  Ramificação DATA WAREHOUSE  (Demo 04)
   raw→cleaned→curated                    State Machine:
   (Athena)                                 1. Glue job: raw → modelo dimensional (S3)
                                            2. COPY no Redshift (Data API)
                                            3. verificação
                                                     │
                                                     ▼
                                            Amazon Redshift Serverless
                                            (modelo estrela: BI)
```

> As duas ramificações são **independentes e paralelas**: partem de `raw/` e não se
> atrapalham. A Demo 01 e a Demo 02 (Lake Formation) **não são modificadas**.

---

## Dois métodos de ingestão no Redshift (ambos discutidos no módulo)

Esta demo usa o padrão **COPY a partir do S3 via Redshift Data API**:
- O Glue job escreve o modelo dimensional no S3 (como JSON/CSV).
- O Step Functions executa comandos `COPY` no Redshift com a **Redshift Data API**
  (sem precisar colocar o job na VPC do Redshift).

O outro método (conector/JDBC do Glue escrevendo direto no Redshift) é mencionado
como alternativa no roteiro, para contraste.

---

## Modelo dimensional (esquema estrela) no Redshift

A partir da zona curada constrói-se um modelo estrela clássico:

**`dim_student`** — uma linha por estudante
| coluna          | origem                        |
|-----------------|-------------------------------|
| student_id (PK) | curated.student_id            |
| student_name    | curated.student_name          |
| student_email   | curated.student_email         |
| region          | curated.region                |
| country         | curated.country               |

**`dim_course`** — uma linha por curso
| coluna           | origem                       |
|------------------|------------------------------|
| course_id (PK)   | hash/slug de course_name     |
| course_name      | curated.course               |

**`fact_engagement`** — uma linha por evento (tabela de fatos)
| coluna           | origem                       |
|------------------|------------------------------|
| event_id         | curated.event_id             |
| student_id (FK)  | → dim_student                |
| course_id (FK)   | → dim_course                 |
| event_type       | curated.event_type           |
| event_ts         | curated.event_ts             |
| event_date       | curated.event_date           |
| study_minutes    | curated.study_minutes        |
| score            | curated.score                |
| engagement_level | curated.engagement_level     |
| is_completed     | curated.is_completed         |

Chaves de distribuição/ordenação (explicadas no roteiro):
- `fact_engagement`: `DISTKEY(student_id)`, `SORTKEY(event_date)`.
- Dimensões pequenas: `DISTSTYLE ALL`.

---

## Estrutura do repositório

```
demo-04-glue-redshift-stepfunctions/
├── README.md                       Este arquivo
├── docs/
│   └── RUNBOOK.md                  Guia operacional passo a passo (bash + PowerShell)
├── infra/
│   └── redshift-stepfn-demo.yaml   CloudFormation: Redshift Serverless, Glue job,
│                                   State Machine, regra EventBridge, papéis
├── src/
│   └── glue/
│       └── curated_to_dimensional.py  Glue job: curated → modelo estrela (S3)
├── sql/
│   ├── 00-create-schema.sql        DDL de dim_student, dim_course, fact_engagement
│   └── 10-analytics-queries.sql    Consultas de negócio sobre o modelo estrela
└── scripts/
    ├── bash/                       Scripts .sh (Linux/macOS/Git Bash)
    │   ├── deploy.sh               Implanta o stack e envia o script do Glue
    │   ├── load-redshift.sh        Carga manual no Redshift (Glue + DDL + COPY)
    │   └── query-redshift.sh       Consulta o modelo estrela via Data API
    ├── powershell/                 Scripts .ps1 (Windows)
    │   ├── deploy.ps1
    │   ├── load-redshift.ps1
    │   └── query-redshift.ps1
    └── _format_result.py           Formatador do resultado da Data API
```

> O passo a passo operacional completo está em
> **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**.

---

## Relação com as demos anteriores (sem impacto)

- **Não modifica** a Demo 01 nem seus dados/tabelas/crawlers.
- **Não mexe** no Lake Formation nem no modo híbrido da Demo 02.
- Lê de `curated/` (que a Demo 01 já produz) e a partir daí constrói o modelo.
- Se a Demo 01 estiver em modo híbrido ou sem registro no LF, o Glue job desta
  demo lê `curated/` por IAM sem problema.

> Pré-requisito: a Demo 01 implantada e com dados em `curated/`.
