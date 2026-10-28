# Demo 02 — Lake Formation Access Control

Curso: **Data Engineering on AWS** · Domínio de exemplo: plataforma de cursos online

Esta demo complementa a [Demo 01](../demo-01-datalake-foundations). Pega o data lake
já catalogado e adiciona **controle de acesso de granularidade fina com AWS Lake
Formation**, demonstrando os **dois modelos de permissões** do Lake Formation sobre
**a mesma tabela curada**:

- **Named Resource** (acesso por recurso do catálogo: banco / tabela / colunas).
- **LF-TBAC** (Tag-Based Access Control: permissões sobre **LF-Tags**).

---

## Relação com a Demo 01 (Export / Import)

A Demo 01 publica seus recursos como **Exports** do CloudFormation. Esta demo os
**importa** com `Fn::ImportValue`, então **nada é duplicado**: governa-se a mesma
tabela curada que o pipeline da Demo 01 já produziu.

| Export da Demo 01                             | O que é                        |
|-----------------------------------------------|--------------------------------|
| `aws-class-datalake-BucketName`              | Bucket do data lake            |
| `aws-class-datalake-BucketArn`               | ARN do bucket (para registrar) |
| `aws-class-datalake-GlueDatabase`            | Banco de dados do Glue         |
| `aws-class-datalake-CuratedTableName`        | Tabela curada a governar (`curated_curated`) |
| `aws-class-datalake-AthenaResultsBucketName` | Resultados do Athena           |
| `aws-class-datalake-AthenaWorkGroup`         | Workgroup do Athena            |

> **Ordem de implantação:** primeiro a Demo 01 (com seus exports já publicados),
> depois esta Demo 02. Se a Demo 01 não estiver implantada, esta falha ao importar.

---

## Named Resource e LF-Tags podem ser usados ao mesmo tempo?

Sim, com uma ressalva importante:

- São **duas formas de conceder permissões** sobre os mesmos objetos do catálogo.
  O Lake Formation avalia as permissões de um principal como a **união** do que ele
  recebe por Named Resource e por LF-Tags. **Podem coexistir na mesma conta e
  inclusive sobre a mesma tabela, para principals distintos.**
- A **única restrição rígida**: *um mesmo principal* **não** pode receber permissões
  Named-Resource e Tag-Based **sobre o mesmo recurso**. O Lake Formation rejeita.

Por isso esta demo usa **um papel por modelo** sobre a mesma tabela:

| Papel                             | Modelo          | O que vê                                           |
|-----------------------------------|-----------------|----------------------------------------------------|
| `aws-class-lf-admin`             | Administrador   | Tudo. Administra o Lake Formation.                 |
| `aws-class-lf-named-resource`    | Named Resource  | A tabela **sem** `student_email` nem `cpf_hash`.   |
| `aws-class-lf-lftags`            | LF-Tags (TBAC)  | Só colunas não-PII e **só linhas** de `BR-SP`.     |

Ao usar um papel distinto por modelo **não** se viola a restrição: cada papel aplica
um único modelo sobre a tabela. A separação por papel é o que torna o cenário válido
no Lake Formation, não é cosmética.

---

## Modelo de permissões da demo

### Papel Named Resource — `aws-class-lf-named-resource`
Permissão **SELECT por recurso**, com **column-level security**: concedem-se todas
as colunas **exceto** `student_email` e `cpf_hash` (as PII). Demonstra a abordagem
clássica "escolho a tabela e as colunas".

### Papel LF-Tags — `aws-class-lf-lftags`
Definem-se duas LF-Tags e etiquetam-se os objetos:

| LF-Tag        | Valores                          | Onde se atribui                          |
|---------------|----------------------------------|------------------------------------------|
| `sensitivity` | `pii`, `non_pii`                 | Colunas: PII em `student_email`,`cpf_hash` |
| `zone`        | `raw`, `cleaned`, `curated`      | A tabela curada → `curated`              |

O papel recebe permissão sobre a **expressão de tags** `sensitivity=non_pii` e
`zone=curated`, de modo que vê a tabela curada mas **não** as colunas PII.
(O filtro por linha `region='BR-SP'` é mostrado como passo manual opcional no
roteiro, porque o row-level filter se associa ao grant.)

---

## Estrutura do repositório

```
demo-02-lakeformation-access-control/
├── README.md                       Este arquivo
├── docs/
│   ├── RUNBOOK.md                  Guia operacional passo a passo (bash + PowerShell)
│   ├── GUION-DEMO.md               Roteiro da demonstração ao vivo
│   ├── FASES-HIBRIDO.md            Sequência só-LF vs. híbrido (3 fases)
│   └── ROW-LEVEL-MANUAL.md         Passo a passo de row-level security
├── infra/
│   └── lakeformation-demo.yaml      CloudFormation: todo o controle de acesso LF
├── sql/
│   ├── 10-named-resource.sql        Consultas para testar com o papel Named Resource
│   └── 20-lftags.sql                Consultas para testar com o papel LF-Tags
└── scripts/
    ├── bash/                        Scripts .sh (Linux/macOS/Git Bash)
    │   ├── deploy.sh                Implanta o stack da Demo 02
    │   ├── enable-hybrid.sh         Ativa o modo híbrido (IAM + LF)
    │   ├── disable-hybrid.sh        Volta ao modo só Lake Formation
    │   └── whoami.sh                Mostra a identidade/papel atual
    └── powershell/                  Scripts .ps1 (Windows)
        ├── deploy.ps1
        ├── enable-hybrid.ps1
        ├── disable-hybrid.ps1
        └── whoami.ps1
```

> O passo a passo operacional completo está em
> **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**.

---

## Guia da demo (switch role no console)

> Pré-requisito: o **principal que implanta** esta demo fica como Data Lake
> Admin, para poder criar location, tags e grants. Ver "Notas de implantação".

1. **Ponto de partida (admin):** com sua identidade normal (ou o papel admin), mostre
   no Athena que a tabela curada tem colunas sensíveis (`student_email`,
   `cpf_hash`, `region`).
2. **Switch para o papel Named Resource** (`aws-class-lf-named-resource`):
   - Execute `sql/10-named-resource.sql`.
   - `SELECT *` funciona mas **não** aparecem `student_email` nem `cpf_hash`
     (column-level security por recurso).
3. **Switch para o papel LF-Tags** (`aws-class-lf-lftags`):
   - Execute `sql/20-lftags.sql`.
   - As PII também são ocultadas, mas o acesso foi concedido por **tags**, não por
     seleção de colunas. Mostre as LF-Tags no console do Lake Formation para
     explicar o porquê.
4. **Contraste:** mesma tabela, dois papéis, dois modelos, resultados equivalentes
   nas PII mas governados de forma distinta. Explique quando cada um convém
   (named = controle pontual; tags = governança em escala por classificação).

Como fazer switch role no console: menu de conta (canto superior direito) →
**Switch role** → Account = sua conta, Role = o nome do papel. Ou use os links
que o `scripts/whoami` imprime após a implantação.

---

## Notas de implantação (IMPORTANTE)

O Lake Formation tem requisitos que convém conhecer:

- **Data Lake Admin:** quem implanta precisa poder administrar o Lake Formation. O
  template adiciona como administradores o **papel admin da demo** e o
  **principal que executa o stack** (parâmetro `DeployerPrincipalArn`).
- **Modo de controle de acesso:** em contas novas o Lake Formation pode estar em
  modo "IAM access control" (`IAMAllowedPrincipals`). Para que as permissões de
  granularidade fina realmente se apliquem, esta demo **registra a location** e cria
  os grants explícitos. Se você já havia mexido no Lake Formation, verifique que
  `IAMAllowedPrincipals` não esteja concedido sobre este banco/tabela (anularia a
  granularidade fina).
- **Registro da location:** o bucket da Demo 01 é registrado como
  *data location* usando um papel de serviço. Isso **não** foi feito na Demo 01 de
  propósito (lá o acesso era IAM puro); é justamente o que muda aqui.
- **Athena com switch role:** cada papel da demo inclui permissões do Athena e
  acesso ao bucket de resultados para que você possa executar consultas após o switch.

Parâmetros do stack:

| Parâmetro               | Default                     | Descrição                                    |
|-------------------------|-----------------------------|----------------------------------------------|
| `DeployerPrincipalArn`  | (obrigatório)               | ARN do seu usuário/papel que implanta → admin. |
| `RowFilterRegion`       | `BR-SP`                     | Região para o filtro de linha opcional.      |
| `TrustedPrincipalArn`   | (conta atual root)          | Quem pode fazer `sts:AssumeRole` aos papéis. |
