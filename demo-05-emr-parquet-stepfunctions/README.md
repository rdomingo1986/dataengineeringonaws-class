# Demo 05 — EMR Serverless + Parquet + Step Functions

Curso: **Data Engineering on AWS** · Domínio de exemplo: plataforma de cursos online

Segunda **ramificação analítica em paralelo** do data lake (ao lado da de Redshift da
[Demo 04](../demo-04-glue-redshift-stepfunctions)). Quando o pipeline da
[Demo 01](../demo-01-datalake-foundations) termina de curar os dados, esta demo:

1. Orquestra com **Step Functions** um job de **Amazon EMR Serverless** (Spark) que
   reescreve a zona curada (JSON) para **Parquet** (colunar, comprimido).
2. Dispara um **Glue Crawler** que cataloga a tabela Parquet.
3. Permite **comparar no Athena** a velocidade e os bytes varridos entre a
   tabela JSON e a tabela Parquet.

```
                         raw (grande) → [Demo01] jobs → curated/ (JSON)
                                             │ (evento: job cleaned->curated SUCCEEDED)
                   ┌─────────────────────────┼───────────────────────────┐
                   ▼                                                      ▼
         [Demo04] State Machine                              [Demo05] State Machine (esta)
         → modelo estrela → Redshift                         → EMR Serverless: JSON→Parquet
                                                             → Glue Crawler → tabela parquet_*
                                                                  │
                                                                  ▼
                                                        Athena: comparar JSON vs Parquet
```

> Duas State Machines **independentes** escutam o **mesmo evento** (fim do job
> cleaned→curated) e rodam em paralelo, com destinos distintos (Redshift vs
> Parquet). Não se atrapalham. As Demos 01 e 04 não são modificadas.

---

## Por que EMR Serverless (e não EMR clássico)

- Sem cluster para provisionar nem VPC para configurar: inicia em segundos, paga por
  job, para automaticamente quando fica ocioso (5 min). Muito mais barato e robusto
  para uma demo do que subir um cluster EC2.
- O Step Functions tem integração nativa `startJobRun.sync`: espera o job Spark
  terminar antes de seguir para o crawler.

---

## Estrutura

```
demo-05-emr-parquet-stepfunctions/
├── README.md
├── docs/
│   └── RUNBOOK.md                  Guia operacional passo a passo (bash + PowerShell)
├── infra/
│   └── emr-parquet-demo.yaml       CFN: EMR Serverless app, crawler, State Machine, regra EventBridge, papéis
├── src/
│   └── emr/
│       └── curated_json_to_parquet.py  Job PySpark: curated JSON → Parquet (particionado por event_date)
├── sql/
│   └── comparacao-json-vs-parquet.sql  Consultas de comparação (tempo + bytes varridos)
└── scripts/
    ├── bash/                       Scripts .sh (Linux/macOS/Git Bash)
    │   ├── deploy.sh               Envia o script EMR + implanta o stack
    │   └── run-pipeline.sh         Dispara a State Machine manualmente (para testar)
    └── powershell/                 Scripts .ps1 (Windows)
        ├── deploy.ps1
        └── run-pipeline.ps1
```

> O passo a passo operacional completo está em
> **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**.

---

## Guia da demo

### 1. Implantar
```bash
./scripts/bash/deploy.sh          # Linux/macOS/Git Bash
```
```powershell
.\scripts\powershell\deploy.ps1   # Windows
```
Cria a aplicação EMR Serverless, o crawler Parquet, a State Machine e a regra
EventBridge.

> **Pré-requisitos:**
> - **Demo 01** implantada (exports do bucket/DB) e com dados em `curated/`.
> - **Demo 02** implantada: o bucket está registrado no Lake Formation, então
>   o crawler precisa de permissões de LF (não basta IAM+S3). O template as concede
>   ao papel do crawler com `AWS::LakeFormation::PrincipalPermissions`
>   (DATA_LOCATION_ACCESS + CREATE_TABLE). Para que o CloudFormation possa criar
>   esses grants, quem implanta deve ser **Data Lake Administrator** (é, se implantou
>   a Demo 02 com seu ARN como `DeployerPrincipalArn`).

### 2. Executar a ramificação Parquet
Duas formas:
- **Automática**: ao rodar o pipeline da Demo 01 (enviar dados para raw/), quando
  o job cleaned→curated termina, esta State Machine dispara sozinha (em paralelo à
  de Redshift).
- **Manual** (para testar sem reexecutar o data lake):
  ```bash
  ./scripts/bash/run-pipeline.sh          # Linux/macOS/Git Bash
  ```
  ```powershell
  .\scripts\powershell\run-pipeline.ps1   # Windows
  ```
Acompanhe o progresso no console do Step Functions: `RunEmrJob` (Spark, espera) →
`StartCrawler` → polling até `READY` → `Success`.

### 3. Verificar a tabela Parquet
```
SHOW TABLES IN aws_class_datalake;
```
Deve aparecer uma tabela `parquet_*` nova (nome exato conforme o crawler).

### 4. Comparar JSON vs Parquet no Athena (o que importa)
Execute as consultas de `sql/comparacao-json-vs-parquet.sql`, cada uma sobre
a tabela JSON e sobre a Parquet. Para cada uma, olhe no console do Athena:
- **Run time** (tempo).
- **Data scanned** (bytes varridos) — a métrica-chave: o Parquet varre uma
  fração do que o JSON varre. Como o Athena cobra por bytes varridos, o Parquet
  é mais rápido **e** mais barato.

> Com volume (centenas de milhares de linhas, o dataset grande do curso) a
> diferença é claramente visível.

---

## Conceitos do módulo que esta demo cobre

- **Amazon EMR Serverless**: Spark gerenciado sem cluster; ideal para
  transformações em escala pontuais.
- **Parquet vs JSON**: formato colunar comprimido vs linha/texto. Impacto no
  desempenho e no custo de consulta.
- **Step Functions multi-serviço**: orquestra o EMR (`.sync`) e o crawler do Glue
  (start + polling) em um único fluxo, com retentativas.
- **Ramificações paralelas a partir de uma mesma origem**: Redshift (Demo 04) e
  Parquet (Demo 05) disparadas pelo mesmo evento, independentes.

> Custo: o EMR Serverless paga por uso e para automaticamente; ainda assim, apague o
> stack ao terminar os testes (ver teardown geral).
