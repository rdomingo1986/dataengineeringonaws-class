# Roteiro de demonstração — Demo 01: Data Lake Foundations

> Curso **Data Engineering on AWS** · Cliente **plataforma de cursos online**
> Duração estimada ao vivo: 20–25 min.
> Objetivo didático: construir o data lake com **AWS Glue (PySpark)** e, sobretudo,
> **entender de onde vêm as permissões quando NÃO há Lake Formation**, usando
> **um papel IAM por zona**. Isso prepara o contraste da Demo 02.

---

## 0. Antes de começar (checklist)

- Stack `aws-class-datalake-demo` implantado (`UPDATE_COMPLETE`).
- EventBridge habilitado no bucket (feito por `scripts/deploy` ou pelo comando
  `put-bucket-notification-configuration`).
- Dados de amostra enviados e pipeline executado (há objetos em `raw/`,
  `cleaned/`, `curated/`).
- Crawlers executados: existem `raw_raw`, `cleaned_cleaned`, `curated_curated`
  no banco `aws_class_datalake`.
- Console do Athena no workgroup `aws-class-datalake-wg`.

Nomes de referência:
- Bucket: `aws-class-datalake-<AccountId>-us-east-1`
- Banco de dados (Glue): `aws_class_datalake`
- Tabelas: `raw_raw`, `cleaned_cleaned`, `curated_curated`
- Papéis por zona (switch role):
  - `aws-class-raw-data-engineer` → zona `raw/` (perfil: Data Engineer)
  - `aws-class-cleaned-data-analyst` → zona `cleaned/` (perfil: Data Analyst)
  - `aws-class-curated-bi-analyst` → zona `curated/` (perfil: BI Analyst)

---

## 1. O problema de negócio (1 min)

A plataforma de cursos online recebe eventos da sua plataforma de aprendizagem: logins, lições,
quizzes, vídeo. Chegam **"sujos"** (datas mistas, cursos inconsistentes, nulos,
duplicados). Queremos levá-los a um estado **curado e consultável** para analytics
de engagement, sem tocar na aplicação de origem.

---

## 2. Passeio pelas zonas do data lake (2 min)

Abra o bucket no console do S3 e mostre as três zonas:

- `raw/` — dados brutos como chegam (JSON Lines, sem limpar).
- `cleaned/` — já normalizados (primeiro Glue job).
- `curated/` — enriquecidos e particionados por `event_date=` (segundo Glue job).

**Mensagem:** uma única "casa" (bucket) com três "cômodos" (prefixos) que
representam o grau de refinamento do dado.

---

## 3. A arquitetura do pipeline (3 min)

O processamento usa **AWS Glue (PySpark)** encadeado por **EventBridge**:

```
  Você envia objeto a raw/
        │  (S3 emite evento ao EventBridge)
        ▼
  EventBridge  ──► Lambda disparadora (glue-trigger)
        │               │  glue:StartJobRun
        ▼               ▼
        │        Glue job raw->cleaned (PySpark)  ──► escreve cleaned/
        │                                                    │
        │  (cleaned/ emite evento ao EventBridge)            ▼
        └──────► Lambda disparadora ──► Glue job cleaned->curated ──► curated/
```

Pontos a explicar:
- **O S3 não pode invocar um Glue job diretamente**, por isso o EventBridge dispara
  uma **Lambda mínima** (`glue-trigger`) que só faz `StartJobRun`. O processamento
  real (limpeza, enriquecimento) fica nos **Glue jobs PySpark**.
- Cada job **reprocessa sua zona de entrada** e escreve a seguinte (idempotente).
- É **event-driven**: ninguém orquestra manualmente; cada escrita dispara a etapa
  seguinte.

> Nota: a versão anterior usava Lambdas para as transformações (preservada em
> `legacy/` como referência). Migrou-se para Glue para um pipeline mais
> representativo de engenharia de dados real.

---

## 4. O pipeline em ação (3 min)

1. Envie `data/student-events-batch-1.json` a `raw/student-events/...`
   (ou use `scripts/powershell/upload-sample-data.ps1` / `scripts/bash/upload-sample-data.sh`).
2. Abra o objeto bruto e mostre como está "sujo" (datas mistas, duplicado
   `evt-0002`, registro lixo `evt-0005`, `duration_seconds: "a"`).
3. Mostre o Glue job rodando no console (ou
   `aws glue get-job-runs --job-name aws-class-raw-to-cleaned`).
4. Mostre o resultado em `cleaned/` (datas ISO, cursos normalizados, sem
   duplicados, sem lixo) e em `curated/` (métricas derivadas, `cpf` com hash,
   particionado por `event_date`).

---

## 5. Catalogação com Glue (2 min)

1. Execute os crawlers (`scripts/powershell/run-crawlers.ps1` / `scripts/bash/run-crawlers.sh`) ou mostre-os já executados.
2. No Glue, abra o banco `aws_class_datalake` e mostre as tabelas e seu schema.

**Mensagem-chave (importante para o curso!):** o **Glue Data Catalog é só
METADADOS**. Descreve *onde* estão os dados (caminho S3), *que forma* têm
(colunas, tipos) e *como* estão particionados. **O catálogo NÃO controla o
acesso aos dados.** É um mapa, não uma fechadura.

---

## 6. As permissões IAM por zona — o coração da demo (6 min)

> Não use o usuário admin: com admin você vê tudo e nada é demonstrado. Use
> **switch role** para cada papel de zona e ver o efeito real das permissões.

Cada papel representa um **perfil** e só tem `s3:GetObject` sobre **seu prefixo**.
Assim se demonstra que, sem Lake Formation, o acesso é isolado **separando os dados
por prefixo** e dando a cada um o seu.

### 6.1 Data Engineer — papel `aws-class-raw-data-engineer`
Switch role para este papel e no Athena:
```sql
SELECT * FROM aws_class_datalake.raw_raw LIMIT 10;
```
- **Funciona**: vê os dados brutos e sujos (sua zona).
- Agora tente ler outra zona:
  ```sql
  SELECT * FROM aws_class_datalake.curated_curated LIMIT 10;
  ```
- **Falha** com erro ao ler o S3: o IAM dele não permite `GetObject` fora de
  `raw/`. Mas ATENÇÃO: no catálogo **ele vê que a tabela existe** (metadados).

> Ponto de ouro: *"Posso VER a tabela no catálogo mas NÃO ler seus dados."*
> Isso prova que o catálogo descreve e IAM+S3 autorizam, separadamente.

### 6.2 Data Analyst — papel `aws-class-cleaned-data-analyst`
Switch role. Só pode ler `cleaned_cleaned`:
```sql
SELECT * FROM aws_class_datalake.cleaned_cleaned LIMIT 10;   -- funciona
SELECT * FROM aws_class_datalake.raw_raw LIMIT 10;           -- falha (fora de cleaned/)
```

### 6.3 BI Analyst — papel `aws-class-curated-bi-analyst`
Switch role. Só `curated_curated`:
```sql
SELECT * FROM aws_class_datalake.curated_curated LIMIT 10;   -- funciona
```
Repare: vê `student_email`, `cpf_hash`, `region` **sem nenhum filtro**. Lance a
pergunta do curso:

> **Por que este BI Analyst vê TODAS as colunas, inclusive as sensíveis?**

---

## 7. De onde vêm as permissões SEM Lake Formation

Explique, por camadas, o que acontece quando o BI Analyst executa a consulta:

1. **Usar o Athena e ler o catálogo → IAM.** Ações como
   `athena:StartQueryExecution` e `glue:GetTable`. Permitem *ver a definição* e
   *lançar* a consulta.
2. **Ler os dados reais → IAM sobre S3.** O Athena lê os objetos de `curated/`
   **com a identidade do papel**. Como o IAM dele dá `s3:GetObject` sobre
   `curated/*`, vê **tudo**: todas as colunas e linhas.
3. **Não há granularidade fina.** O controle é **binário e no nível do objeto S3**:
   lê o arquivo completo ou nada. Não há forma nativa de ocultar a coluna
   `student_email` nem filtrar linhas por `region` sem truques (views, duplicar
   tabelas, separar prefixos).

### Frase para fixar o conceito

> **Sem Lake Formation: o Glue Data Catalog DESCREVE, e IAM + S3 AUTORIZAM, com
> granularidade do objeto S3 completo. O catálogo não filtra nada.**

```
  Papel de zona (switch role)
      │  athena:StartQueryExecution   (IAM)
      ▼
   Athena ──► Glue Catalog   (METADADOS: caminho, colunas)   [só descreve]
      │
      │  lê os dados COM A IDENTIDADE DO PAPEL
      ▼
   S3  ──►  o IAM do papel tem s3:GetObject sobre <zona>/*?
            SIM → vê TODAS as colunas e linhas dessa zona
            NÃO → "access denied" (mesmo que veja a tabela no catálogo)
```

---

## 8. Encerramento e ponte para a Demo 02 (1 min)

- A Demo 01 entrega um data lake **funcional e catalogado**, com **controle de
  acesso grosso**: IAM + S3, por **objeto/prefixo completo**.
- Isolar acessos obrigou a **separar os dados por zona** e dar a cada papel o seu
  prefixo. Ocultar uma **coluna** (`student_email`) ou filtrar **linhas** (`region`)
  não dá para fazer de forma limpa aqui.
- As colunas sensíveis já estão em `curated_curated` (`student_email`, `cpf_hash`,
  `region`) — prontas para serem governadas na Demo 02.

> Pergunta para deixar no ar: *"E se eu quiser que o BI Analyst veja o engagement
> por curso mas nunca o email nem o CPF dos estudantes, sem duplicar os dados?"*
> → **Demo 02 com Lake Formation.**
