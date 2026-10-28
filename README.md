# Data Engineering on AWS — Demos

Conjunto de **6 demos práticas** que cobrem os pilares de engenharia de dados na
AWS: data lake, governança de acesso, data warehouse, formatos colunares,
orquestração e streaming. Cada demo é um projeto CloudFormation independente, com
seu próprio README, roteiro de apresentação e scripts de implantação.

O domínio de negócio é fictício e comum a todas as demos: uma **plataforma de
cursos online** que gera eventos de atividade dos estudantes (logins, aulas,
quizzes, vídeo, matrículas). As demos levam esses dados de um estado bruto
"sujo" até análises de negócio por vários caminhos.

> **Diagramas de arquitetura:**
> - Cadeia conectada (Demos 01–05):
>   [`diagrams/arquitetura-demos-01-05.png`](diagrams/arquitetura-demos-01-05.png)
>   — gerado por [`diagrams/architecture.py`](diagrams/architecture.py).
> - Demo 06 (streaming, autônoma):
>   [`diagrams/arquitetura-demo06.png`](diagrams/arquitetura-demo06.png)
>   — gerado por [`diagrams/architecture-demo06.py`](diagrams/architecture-demo06.py).

> **Convenção de idioma:** todo o texto explicativo (READMEs, roteiros, comentários,
> descrições) está em **português do Brasil**. O **código executável** (nomes de
> recursos, tabelas, colunas, variáveis, comandos AWS) permanece em **inglês**, por
> padrão de engenharia.

---

## Visão geral das demos

| # | Demo | O que faz | Serviços-chave |
|---|------|-----------|----------------|
| 01 | [Data Lake Foundations](demo-01-datalake-foundations) | Data lake em 3 zonas (raw→cleaned→curated) com pipeline orientado a eventos | S3, Glue (PySpark), EventBridge, Lambda, Athena |
| 02 | [Lake Formation Access Control](demo-02-lakeformation-access-control) | Controle de acesso de granularidade fina sobre a mesma tabela curada | Lake Formation, IAM, Athena |
| 03 | [Redshift Serverless](demo-03-redshift-serverless) | Fundamentos de data warehouse serverless operado pela Data API | Redshift Serverless, Redshift Data API, S3 |
| 04 | [Glue + Redshift + Step Functions](demo-04-glue-redshift-stepfunctions) | Ramificação data warehouse: modelo estrela carregado no Redshift, orquestrado | Glue, Redshift Serverless, Step Functions, EventBridge |
| 05 | [EMR + Parquet + Step Functions](demo-05-emr-parquet-stepfunctions) | Reescrita de JSON para Parquet e comparação de desempenho no Athena | EMR Serverless, Glue Crawler, Step Functions, Athena |
| 06 | [Streaming Analytics](demo-06-streaming-analytics) | Dados em movimento: ingestão e análise em (quase) tempo real | Kinesis Data Streams, Firehose, Lambda, CloudWatch, Athena |

As Demos **01 → 02 → 04 → 05** formam uma cadeia conectada (compartilham o data lake
via `Export`/`ImportValue`). As Demos **03** e **06** são autônomas e independentes.

---

## Demo 01 — Data Lake Foundations

**O que faz:** constrói um data lake em um único bucket S3 com três zonas
(`raw/` → `cleaned/` → `curated/`). Ao subir dados brutos "sujos" (datas em formatos
mistos, duplicados, nulos, lixo) na zona `raw/`, o EventBridge dispara uma Lambda
mínima que inicia Glue jobs PySpark em cadeia: o primeiro limpa (raw→cleaned) e o
segundo enriquece e anonimiza (cleaned→curated). Crawlers do Glue catalogam cada
zona e o Athena consulta o resultado.

**Conceitos que demonstra:**
- Arquitetura de **data lake em zonas** e por que separar bruto / limpo / curado.
- **Pipeline orientado a eventos** (S3 → EventBridge → Glue), desacoplado e declarativo.
- **Limpeza e padronização** de dados sujos com PySpark; hash de PII (CPF).
- **Glue Data Catalog** como camada de metadados consultável pelo Athena.
- Modelo de acesso **IAM + S3 puro**: papéis por zona que só leem o seu prefixo
  (a base da qual a Demo 02 parte para introduzir o Lake Formation).

---

## Demo 02 — Lake Formation Access Control

**O que faz:** pega o data lake catalogado da Demo 01 e adiciona controle de acesso
de granularidade fina com o AWS Lake Formation, sobre a **mesma** tabela curada.
Demonstra os dois modelos de permissão lado a lado — **Named Resource** (por recurso
do catálogo, com column-level security) e **LF-Tags** (Tag-Based Access Control) —
usando um papel IAM por modelo. Inclui um complemento de **row-level security** (Data
cell filter) e a dinâmica de modo **só-LF vs. híbrido**.

**Conceitos que demonstra:**
- O que muda ao **registrar uma location** no Lake Formation (quem controla os dados).
- **Column-level** e **row-level security** sem duplicar dados nem criar views.
- **Named Resource vs. LF-Tags**: controle pontual vs. governança em escala por
  classificação; quando usar cada um e por que não se misturam num mesmo principal.
- Modo **híbrido**: IAM+S3 e Lake Formation convivendo (migração gradual).

---

## Demo 03 — Redshift Serverless

**O que faz:** demo autônoma que ensina os fundamentos do Amazon Redshift Serverless.
Cria um namespace + workgroup via CloudFormation e, usando apenas a **Redshift Data
API** (sem JDBC nem VPC), cria uma tabela de matrículas, carrega dados com `COPY` a
partir do S3 e executa consultas de negócio.

**Conceitos que demonstra:**
- **Redshift Serverless**: capacidade por RPU, pausa automática, sem gerenciar nós.
- **Redshift Data API**: executar SQL de forma assíncrona (executar → status →
  resultado), ideal para automação e scripts/Lambdas.
- **COPY a partir do S3**: o método canônico de ingestão em massa no Redshift.
- **DISTSTYLE / SORTKEY**: otimização física de tabelas.

---

## Demo 04 — Glue + Redshift + Step Functions

**O que faz:** adiciona uma **ramificação data warehouse** em paralelo ao data lake.
Quando o pipeline da Demo 01 termina de curar os dados, uma State Machine do Step
Functions orquestra: um Glue job que transforma a zona curada em um **modelo estrela**
(dim_student, dim_course, fact_engagement) escrito em S3, seguido de comandos `COPY`
que o carregam no Redshift via Data API, com verificação.

**Conceitos que demonstra:**
- A zona `raw` como **fonte da verdade com múltiplos consumidores** (data lake e
  data warehouse partindo dos mesmos dados).
- **Modelagem dimensional** (esquema estrela) para BI em Redshift.
- **Orquestração com Step Functions**: integração `.sync` com Glue, polling da Data
  API, tratamento de erros com Retry/Catch.
- Disparo por **EventBridge** encadeado ao fim do pipeline da Demo 01.

---

## Demo 05 — EMR + Parquet + Step Functions

**O que faz:** segunda ramificação analítica em paralelo. Uma State Machine orquestra
um job de **EMR Serverless** (Spark) que reescreve a zona curada (JSON) em **Parquet**
(colunar, comprimido), e depois um Glue Crawler que cataloga a tabela Parquet. Permite
**comparar no Athena** o tempo e os bytes varridos entre consultar JSON e Parquet.

**Conceitos que demonstra:**
- **EMR Serverless**: Spark gerenciado sem cluster, para transformações pontuais em escala.
- **Parquet vs. JSON**: impacto do formato colunar comprimido no desempenho e, sobretudo,
  no **custo** (o Athena cobra por bytes varridos).
- **Step Functions multi-serviço**: EMR (`.sync`) + crawler do Glue (start + polling).
- **Ramificações paralelas** disparadas pelo mesmo evento, independentes (junto à Demo 04).

---

## Demo 06 — Streaming Analytics

**O que faz:** demo autônoma que mostra o paradigma de **dados em movimento**. Um
produtor simula eventos ao vivo que chegam ao **Kinesis Data Streams** e são
processados por duas ramificações em paralelo: o **Firehose** entrega o stream ao S3
para análise histórica com Athena, e uma **Lambda** consome o stream e publica
métricas no **CloudWatch**, visualizadas num dashboard em quase tempo real.

**Conceitos que demonstra:**
- **Kinesis Data Streams** (modo ON_DEMAND) para ingestão de eventos em tempo real.
- **Dois padrões de consumo do mesmo stream**: entrega para armazenamento (Firehose→S3)
  e processamento em tempo real (Lambda + métricas).
- **Métricas personalizadas + CloudWatch Dashboard** para observabilidade ao vivo.
- **Streaming vs. batch**: tempo real no CloudWatch vs. análise histórica no Athena.

---

## Ordem sugerida e pré-requisitos

1. **Demo 01** primeiro (publica os exports que as Demos 02, 04 e 05 importam).
2. **Demo 02** depois da 01 (registra o bucket no Lake Formation).
3. **Demos 04 e 05** depois da 01 (e a 05 requer a 02, pelos grants de LF ao crawler).
4. **Demos 03 e 06** a qualquer momento (são autônomas).

Cada demo traz seu próprio `README.md` com o guia detalhado, um
`docs/RUNBOOK.md` operacional passo a passo, e scripts em `scripts/bash/` (`.sh`
para Linux/macOS/Git Bash) e `scripts/powershell/` (`.ps1` para Windows) que
implantam e operam o stack.

> **Região/conta:** as demos foram validadas em `us-east-1`. Ajuste a região nos
> scripts se necessário. Ao terminar, apague os stacks para não deixar custo
> (especialmente Redshift, EMR e Kinesis).
