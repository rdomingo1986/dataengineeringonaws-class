# Runbook — Demo 02: Lake Formation Access Control

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

> **Depende da Demo 01.** Esta demo importa Exports da Demo 01 e registra o
> bucket do data lake no Lake Formation. Implante a Demo 01 **antes**. Veja
> "Dependências e integração".

---

## Convenções e nomes de recursos

| Recurso              | Nome / valor                                            |
|----------------------|---------------------------------------------------------|
| Stack CloudFormation | `aws-class-lakeformation-demo`                         |
| Papéis               | `aws-class-lf-admin`, `aws-class-lf-named-resource`, `aws-class-lf-lftags` |
| LF-Tags              | `sensitivity` (pii/non_pii), `zone` (raw/cleaned/curated) |
| Tabela governada     | `curated_curated` (banco `aws_class_datalake`, da Demo 01) |
| Data location        | bucket `aws-class-datalake-<ACCOUNT_ID>-<REGION>` (registrado no LF) |
| Região               | `us-east-1` (ajuste se necessário)                     |

> **Nota sobre shells:** um `.sh` criado no Windows pode ter quebras CRLF e falhar
> no Linux. Em Linux/macOS garanta quebras LF; no Windows prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

**Verificações críticas de dependência:**

1. A **Demo 01 está implantada** e seus Exports existem:
   ```
   aws cloudformation describe-stacks --stack-name aws-class-datalake-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
   aws cloudformation list-exports --region us-east-1 --query "Exports[?starts_with(Name, 'aws-class-datalake-')].Name" --output text
   ```
   Deve existir pelo menos `aws-class-datalake-BucketArn`, `-GlueDatabase` e
   `-CuratedTableName`.
2. A tabela `curated_curated` **existe e tem dados** (a Demo 01 já rodou o
   pipeline e os crawlers).
3. Você sabe o **ARN do principal que implanta** (vira Data Lake Administrator):
   - bash / PowerShell (igual)
     ```
     aws sts get-caller-identity --query Arn --output text
     ```

**Checklist:**
- [ ] AWS CLI v2; credenciais com permissão para CloudFormation, IAM, Lake
      Formation e Athena.
- [ ] Você pode se tornar **Data Lake Administrator** (o deploy adiciona o
      `DeployerPrincipalArn` como admin).

---

## 1. Implantar o stack

Cria os três papéis (admin / named-resource / lf-tags), registra o bucket da
Demo 01 como **data location** no Lake Formation, cria as LF-Tags e os grants
(Named Resource com column-level + LF-Tags por expressão).

- bash
  ```bash
  ./scripts/bash/deploy.sh
  # DEPLOYER_ARN é deduzido do caller; para forçar:
  ./scripts/bash/deploy.sh aws-class-lakeformation-demo us-east-1 arn:aws:iam::<ACCOUNT_ID>:user/<SEU_USUARIO>
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  .\scripts\powershell\deploy.ps1 -DeployerArn arn:aws:iam::<ACCOUNT_ID>:user/<SEU_USUARIO>
  ```

> **Efeito imediato importante:** ao registrar o bucket, o Lake Formation assume
> o controle do acesso aos dados. Os papéis por zona da Demo 01 (IAM+S3)
> **deixam de conseguir ler** até que se ative o modo híbrido (passo 3) ou se
> concedam grants de LF. Isso é intencional e é o ponto didático da demo.

**Verificação:**
```
aws cloudformation describe-stacks --stack-name aws-class-lakeformation-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
aws lakeformation describe-resource --resource-arn arn:aws:s3:::aws-class-datalake-<ACCOUNT_ID>-us-east-1 --region us-east-1 --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
```

---

## 2. Confirmar identidade e consultar (switch role)

Antes de cada bloco, confirme qual papel está ativo:

- bash
  ```bash
  ./scripts/bash/whoami.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\whoami.ps1
  ```

Depois, faça **switch role** no console para `aws-class-lf-named-resource` e
execute `sql/10-named-resource.sql`; repita com `aws-class-lf-lftags` e
`sql/20-lftags.sql`. Detalhes em [`GUION-DEMO.md`](GUION-DEMO.md).

---

## 3. Alternar modo só-LF ↔ híbrido

O modo de acesso **não** é gerenciado pelo CloudFormation (a API `UpdateResource`
rejeita locations com service-linked role). Alterna-se com deregister + register.

- **Híbrido** (IAM+S3 e LF convivem; a Demo 01 volta a funcionar):
  - bash
    ```bash
    ./scripts/bash/enable-hybrid.sh
    ```
  - PowerShell
    ```powershell
    .\scripts\powershell\enable-hybrid.ps1
    ```
- **Só Lake Formation** (só principals com grants de LF leem):
  - bash
    ```bash
    ./scripts/bash/disable-hybrid.sh
    ```
  - PowerShell
    ```powershell
    .\scripts\powershell\disable-hybrid.ps1
    ```

Sequência de demonstração completa (antes/quebra/conserta) em
[`FASES-HIBRIDO.md`](FASES-HIBRIDO.md). Row-level security manual em
[`ROW-LEVEL-MANUAL.md`](ROW-LEVEL-MANUAL.md).

---

## 4. Teardown (remover tudo)

> **ORDEM CRÍTICA:** o stack remove os grants, as LF-Tags e **desregistra a data
> location** (recurso `AWS::LakeFormation::Resource`). Isso devolve o controle do
> bucket ao IAM da Demo 01. Faça o teardown desta Demo 02 **antes** de remover a
> Demo 01.

1. (Se estiver em modo híbrido, não é necessário desfazer antes — o delete do
   stack remove o registro da location de qualquer forma.)
2. Apagar o stack:
   ```
   aws cloudformation delete-stack --stack-name aws-class-lakeformation-demo --region us-east-1
   aws cloudformation wait stack-delete-complete --stack-name aws-class-lakeformation-demo --region us-east-1
   ```
3. **Verificar que a location foi desregistrada** (deve dar erro "not registered"
   ou retornar vazio):
   ```
   aws lakeformation describe-resource --resource-arn arn:aws:s3:::aws-class-datalake-<ACCOUNT_ID>-us-east-1 --region us-east-1
   ```
   Se ainda aparecer registrada, desregistre manualmente:
   ```
   aws lakeformation deregister-resource --resource-arn arn:aws:s3:::aws-class-datalake-<ACCOUNT_ID>-us-east-1 --region us-east-1
   ```

---

## Dependências e integração com outras demos

**Importa da Demo 01** (via `Fn::ImportValue`):

| Export importado                              | Uso nesta demo                   |
|-----------------------------------------------|----------------------------------|
| `aws-class-datalake-BucketArn`               | registrar a data location no LF  |
| `aws-class-datalake-GlueDatabase`            | banco das tabelas governadas     |
| `aws-class-datalake-CuratedTableName`        | tabela `curated_curated` governada |
| `aws-class-datalake-AthenaResultsBucketName` | resultados do Athena para os papéis |

**Efeitos colaterais sobre a Demo 01:**
- Registrar o bucket no LF **quebra** o acesso IAM+S3 dos papéis por zona da
  Demo 01 até ativar o modo híbrido (`enable-hybrid`).
- Se você quiser que o **crawler** da Demo 01 (ou da Demo 05) rode com o bucket
  já registrado, redeploy a Demo 01 com `LakeFormationEnabled=true` para conceder
  grants de LF ao papel do crawler.

**Regras de ordem:**
- **Deploy:** Demo 01 → Demo 02.
- **Teardown:** Demo 02 → Demo 01 (esta desregistra a location primeiro).

**Não publica Exports.** Nenhuma outra demo depende da Demo 02.
