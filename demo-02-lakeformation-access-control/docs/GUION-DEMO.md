# Roteiro de demonstração — Demo 02: Lake Formation Access Control

> Curso **Data Engineering on AWS** · Cliente **plataforma de cursos online**
> Duração estimada ao vivo: 20–25 min.
> Objetivo didático: mostrar **o que o Lake Formation traz** em relação ao modelo
> IAM+S3 da Demo 01, e demonstrar os **dois modelos de permissões**
> (Named Resource vs LF-Tags) sobre a **mesma** tabela curada.

---

## 0. Antes de começar (checklist)

- Demo 01 implantada e com a tabela `curated_curated` populada.
- Stack `aws-class-lakeformation-demo` implantado (`CREATE_COMPLETE`).
- Você tem permissão para fazer **switch role** no console para:
  - `aws-class-lf-admin`
  - `aws-class-lf-named-resource`
  - `aws-class-lf-lftags`
- Console do Athena no workgroup `aws-class-datalake-wg`, banco
  `aws_class_datalake`, tabela `curated_curated`.

Links de switch role: ver os Outputs do stack
(`SwitchRoleConsoleNamed`, `SwitchRoleConsoleTags`).

---

## 1. Relembrando: como eram as permissões na Demo 01 (2 min)

Antes de mexer em nada, relembre a conclusão da Demo 01:

> Sem Lake Formation, o **Glue Data Catalog apenas DESCREVE** os dados, e o
> acesso real é decidido por **IAM + S3** no nível do **objeto inteiro**. Se o seu
> IAM permite ler o objeto em `curated/`, você vê **todas as colunas e todas as
> linhas**. Não há forma nativa de ocultar uma coluna ou uma linha.

Esta demo muda justamente esse modelo.

---

## 2. O que significa "registrar a location" (3 min)

Abra o console do **Lake Formation → Administration → Data lake locations** e
mostre o bucket registrado (`aws-class-datalake-...`).

Explique a mudança fundamental:

- Ao registrar o bucket, você entrega ao Lake Formation a **"chave" do S3**.
  Quem realmente tem permissão de `s3:GetObject` sobre os dados passa a ser um
  **papel de serviço do Lake Formation** (service-linked role), **não** você.
- A partir de agora, **você já não acessa os dados com seu IAM sobre o S3.**
  Para ler dados você precisa de um **grant do Lake Formation**.

### Frase para fixar o conceito

> **Registrar a location = ceder o controle dos dados de IAM/S3 ao Lake
> Formation.** A permissão de dados deixa de ser "posso ler o objeto S3?" e passa
> a ser "o que o Lake Formation me concedeu sobre esta tabela, colunas e linhas?".

---

## 3. O que acontece agora quando você consulta no Athena (2 min)

Compare o fluxo com o da Demo 01:

```
  Papel (switch role)
      │  athena:StartQueryExecution           (IAM: só "usar o Athena")
      ▼
   Athena ──► Glue Catalog   (metadados)
      │
      │  lakeformation:GetDataAccess           (pede permissão ao Lake Formation)
      ▼
   Lake Formation  ──► avalia seus GRANTS (named-resource ou LF-tags)
      │                 decide colunas e linhas permitidas
      ▼
   Retorna credenciais TEMPORÁRIAS já FILTRADAS
      │
      ▼
   Athena lê do S3 SÓ o permitido  → nunca vê as colunas proibidas
```

**Mensagem:** a filtragem ocorre **antes** de o Athena ver os dados. As
colunas/linhas proibidas não se "escondem na UI": simplesmente **não chegam**.

---

## 4. Modelo A — NAMED RESOURCE (5 min)

**Switch role → `aws-class-lf-named-resource`.**
Confirme a identidade: `scripts/powershell/whoami.ps1` (ou `scripts/bash/whoami.sh`,
ou veja no console).

Execute `sql/10-named-resource.sql`:

1. `SELECT * FROM aws_class_datalake.curated_curated LIMIT 20;`
   → A consulta funciona, mas **NÃO aparecem** `student_email` nem `cpf_hash`.
2. Descomente a consulta que pede essas colunas explicitamente → **falha**
   (não concedidas).
3. Consulta de negócio (engagement por curso) → funciona normalmente.

**Explique o porquê:** a este papel foi concedido `SELECT` **sobre o recurso**
(a tabela) mas com **column-level security**: todas as colunas **exceto**
`student_email` e `cpf_hash`. No console do Lake Formation → *Data permissions*
mostre o grant deste papel.

> Named Resource = "escolho explicitamente a tabela e as colunas". Controle
> pontual, muito claro para poucos recursos.

---

## 5. Modelo B — LF-TAGS (Tag-Based Access Control) (6 min)

**Switch role → `aws-class-lf-lftags`.**

Antes de consultar, no Lake Formation → **LF-Tags** mostre:
- Tag `sensitivity` com valores `pii` / `non_pii`.
- Tag `zone` com valores `raw` / `cleaned` / `curated`.
E na tabela `curated_curated`: as colunas `student_email` e `cpf_hash` estão
etiquetadas `sensitivity=pii`; a tabela está etiquetada `zone=curated`.

Execute `sql/20-lftags.sql`:

1. `SELECT *` → novamente **sem** as colunas PII.
2. Consulta de negócio (score por curso) → funciona.

**Explique o porquê (e o contraste):** a este papel **não** se deu a tabela pelo
nome. Concedeu-se `SELECT` sobre uma **expressão de tags**:
`zone = curated` **AND** `sensitivity = non_pii`. Como as colunas PII têm
`sensitivity=pii`, ficam **fora** do alcance → ele não as vê.

> LF-Tags = "classifico os dados e dou acesso por classificação". Governança em
> **escala**: uma política por tag cobre muitas tabelas e colunas presentes e
> futuras.

---

## 6. O contraste, lado a lado (2 min)

| Aspecto                     | Named Resource                     | LF-Tags (TBAC)                          |
|-----------------------------|------------------------------------|-----------------------------------------|
| Como se concede             | Você escolhe tabela/colunas concretas | Define tags e dá acesso por expressão |
| Resultado na demo           | Oculta `student_email`, `cpf_hash` | Oculta as mesmas (pela tag `pii`)       |
| Quando convém               | Poucos recursos, controle pontual  | Muitos recursos, governança em escala   |
| Manutenção ao crescer       | Um grant por recurso               | Etiqueta tabelas novas e elas herdam regras |

**Ponto-chave que costuma ser perguntado:**
> Dá para usar os dois modelos ao mesmo tempo? Sim, na mesma conta e inclusive
> sobre a mesma tabela **para principals distintos** (as permissões se **somam**).
> A **única** restrição: um **mesmo** principal não pode receber named-resource
> **e** tag-based sobre o **mesmo** recurso. Por isso esta demo usa **um papel por
> modelo**.

---

## 7. (Opcional) Row-level: só linhas de uma região (3 min)

Para mostrar segurança no nível de **linha**: no Lake Formation crie um
**Data cell filter** sobre `curated_curated` com a expressão `region = 'BR-SP'` e
conceda-o a um dos papéis. Execute de novo no Athena:

```sql
SELECT region, COUNT(*) FROM aws_class_datalake.curated_curated GROUP BY region;
```

Antes do filtro: aparecem várias regiões. Depois: **só** `BR-SP`.

> Isso demonstra a granularidade mais fina: não só colunas, também **linhas** (e
> células), algo impossível no modelo IAM+S3 da Demo 01 sem duplicar dados.

---

## 8. Encerramento: o que o Lake Formation traz (1 min)

- **Centraliza** a permissão de dados no catálogo (um único console de governança).
- **Granularidade fina**: banco → tabela → **coluna** → **linha** → célula, sem
  duplicar dados nem criar views.
- **Desacopla** a permissão do IAM/S3 cru: os analistas não precisam de
  `s3:GetObject`; eles pedem acesso governado.
- **Escala** com LF-Tags: você classifica uma vez e as regras se aplicam a tudo o
  que está etiquetado, presente e futuro.
- **Auditável**: fica claro quem pode ver o quê e por quê.

### A ideia que resume as duas demos

> **Demo 01 (sem LF):** o catálogo descreve, IAM + S3 autorizam no nível do
> objeto inteiro. Ver o objeto = ver tudo.
>
> **Demo 02 (com LF):** a permissão de dados é **governada pelo catálogo** via Lake
> Formation, com granularidade de coluna e linha, e o Athena recebe os dados **já
> filtrados**.
