# Passo a passo manual — Row-level security (Data cell filter)

> Complemento da Demo 02. Esta é a parte **final** do roteiro: depois de mostrar
> segurança no nível de **coluna** (Named Resource e LF-Tags), aqui mostramos a
> granularidade mais fina, no nível de **linha**, com um **Data cell filter** do
> Lake Formation. Tudo é feito à mão no console para ensinar o "antes e depois".

Objetivo: fazer um papel ver **somente as linhas da região `BR-SP`** da tabela
`curated_curated`, em vez de todas as regiões.

---

## Conceitos (explique em 1 min)

- Um **Data cell filter** define, sobre uma tabela: (a) quais **colunas** se veem e
  (b) quais **linhas** se veem, por meio de uma expressão tipo `WHERE` (row filter).
- Concede-se dando `SELECT` **sobre o filtro** (não sobre a tabela direta).
- **O Lake Formation soma permissões** de um mesmo principal. Se o papel já tinha um
  `SELECT` sobre a tabela (dos passos anteriores), esse grant continuaria deixando
  ele ver todas as linhas. Por isso, para que o filtro por linha tenha efeito,
  primeiro é preciso **revogar** o grant anterior desse papel.

Usaremos o papel **`aws-class-lf-named-resource`** para este exemplo.

---

## Passo 0 — Linha de base (ANTES do filtro)

1. No console, **switch role** para `aws-class-lf-named-resource`.
2. No Athena (banco `aws_class_datalake`, workgroup `aws-class-datalake-wg`):
   ```sql
   SELECT region, COUNT(*) AS linhas
   FROM aws_class_datalake.curated_curated
   GROUP BY region
   ORDER BY region;
   ```
3. Observe que aparecem **várias regiões** (BR-SP, BR-RJ, BR-MG, BR-RS, BR-PR…).
   Este é o "antes".

> Deixe esta aba à mão para repetir a consulta no final.

---

## Passo 1 — Revogar o grant prévio do papel (como admin)

> Faça isso com sua identidade de admin (ou switch role para `aws-class-lf-admin`).
> Isso evita que o grant de colunas anterior "encubra" o efeito do filtro.

1. Console do **Lake Formation → Permissions → Data permissions**.
2. Procure a linha onde:
   - **Principal** = `aws-class-lf-named-resource`
   - **Resource** = tabela `curated_curated` (banco `aws_class_datalake`)
3. Selecione-a e clique em **Revoke**. Confirme.

Resultado: o papel fica **sem** acesso à tabela (que ele recupera via o filtro
no passo 3).

---

## Passo 2 — Criar o Data cell filter (como admin)

1. Console do **Lake Formation → Data catalog → Data filters** (também acessível
   pela tabela: *Tables → `curated_curated` → View data filters*).
2. **Create data filter** com estes valores:
   - **Data filter name:** `br-sp-only`
   - **Target database:** `aws_class_datalake`
   - **Target table:** `curated_curated`
   - **Column-level access:**
     - Escolha **"Access to all columns"** (assim o exemplo isola o efeito de
       LINHA; as colunas não são tocadas aqui).
       *(Opcional avançado: você poderia excluir `student_email`/`cpf_hash` aqui
       para combinar linha + coluna em um único filtro.)*
   - **Row filter expression:**
     ```
     region = 'BR-SP'
     ```
3. **Create**.

---

## Passo 3 — Conceder SELECT sobre o filtro ao papel (como admin)

1. **Lake Formation → Permissions → Data permissions → Grant**.
2. **Principals:** IAM role `aws-class-lf-named-resource`.
3. **LF-Tags or catalog resources:** escolha **Named Data Catalog resources**.
   - **Databases:** `aws_class_datalake`
   - **Tables:** `curated_curated`
   - **Data filters:** selecione **`br-sp-only`**.
4. **Table permissions:** marque **Select**.
5. **Grant**.

> Ao conceder sobre o **filtro**, o papel só poderá ler o que o filtro
> permite: todas as colunas, mas **só linhas com `region = 'BR-SP'`**.

---

## Passo 4 — Linha de base (DEPOIS do filtro)

1. Volte à sessão com **switch role `aws-class-lf-named-resource`**.
   (Se você tinha o console aberto, atualize; as credenciais da sessão do
   Athena precisam ser renovadas para pegar a nova permissão.)
2. Repita a consulta do Passo 0:
   ```sql
   SELECT region, COUNT(*) AS linhas
   FROM aws_class_datalake.curated_curated
   GROUP BY region
   ORDER BY region;
   ```
3. Agora deve aparecer **só `BR-SP`**. Esse é o "depois".

4. (Reforço) Mostre que um `SELECT *` também fica limitado a essas linhas:
   ```sql
   SELECT student_id, course, region
   FROM aws_class_datalake.curated_curated
   LIMIT 50;
   ```
   Todas as linhas retornadas são de `BR-SP`.

---

## Encerramento do ponto

> Passamos de **coluna** (quais campos você vê) para **linha** (quais registros
> você vê), tudo governado pelo Lake Formation, **sem duplicar dados nem criar
> views**. No modelo IAM+S3 da Demo 01 isso era impossível sem separar os dados
> fisicamente. Esta é a granularidade mais fina que o Lake Formation traz.

---

## Como DESFAZER (voltar ao estado da demo)

Para deixar o papel como antes do row-level (útil se você repetir a demo):

1. **Lake Formation → Data permissions:** **Revoke** o grant do filtro
   `br-sp-only` do papel `aws-class-lf-named-resource`.
2. (Opcional) **Data filters:** apague o filtro `br-sp-only`.
3. Conceda de novo o **grant column-level** original ao papel. Como esse grant foi
   criado pelo CloudFormation (`NamedResourceGrant`), a forma mais limpa é:
   ```cmd
   aws cloudformation deploy --template-file infra\lakeformation-demo.yaml ^
     --stack-name aws-class-lakeformation-demo --capabilities CAPABILITY_NAMED_IAM ^
     --region us-east-1 ^
     --parameter-overrides DeployerPrincipalArn=arn:aws:iam::<ACCOUNT_ID>:user/<SEU_USUARIO> CuratedTableNameOverride=curated_curated
   ```
   > Nota: o CloudFormation detecta que o grant foi revogado fora do template.
   > Um redeploy sem mudanças pode não recriá-lo; se ele não reaparecer, conceda o
   > `SELECT` column-level à mão (excluindo `student_email` e `cpf_hash`) pelo
   > console do Lake Formation.
