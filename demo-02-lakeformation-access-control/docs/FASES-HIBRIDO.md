# Demonstração: só-LF vs. híbrido (as três fases)

> Complemento da Demo 02. Mostra o que acontece com o acesso da Demo 01 (IAM+S3)
> quando o bucket é registrado no Lake Formation, e como o **modo híbrido** faz
> os dois modelos conviverem. É a sequência "antes / quebra / conserta".

---

## Por que a mudança de modo NÃO está no CloudFormation

O CloudFormation **não consegue** mudar `HybridAccessEnabled` sobre uma data
location registrada com o **service-linked role**: a API `UpdateResource` exige um
`RoleArn` explícito e rejeita o service-linked role (`"Resource managed by
Service Linked Role"`). Por isso a mudança de modo é feita **fora** do
CloudFormation, com `deregister-resource` + `register-resource`, que é o que os
scripts fazem:

- `scripts/{bash/enable-hybrid.sh | powershell/enable-hybrid.ps1}`  → modo **híbrido** (IAM + LF convivem)
- `scripts/{bash/disable-hybrid.sh | powershell/disable-hybrid.ps1}` → modo **só Lake Formation**

> Os grants e LF-Tags da Demo 02 **são preservados** ao mudar de modo: estão
> associados às tabelas do catálogo, não à location.

---

## FASE 1 — Demo 01 sozinha (IAM + S3 puro)

Estado: a Demo 02 **não** implantada. O bucket NÃO está registrado no Lake
Formation.

Switch role para cada papel de zona da Demo 01 e consulte no Athena:
```sql
SELECT * FROM aws_class_datalake.raw_raw LIMIT 10;        -- raw-data-engineer: OK
SELECT * FROM aws_class_datalake.cleaned_cleaned LIMIT 10; -- cleaned-data-analyst: OK
SELECT * FROM aws_class_datalake.curated_curated LIMIT 10; -- curated-bi-analyst: OK
```
Cada papel lê a **sua** zona por IAM+S3. Este é o ponto de partida.

---

## FASE 2 — Implantar a Demo 02 (modo só-LF): a Demo 01 QUEBRA

Implante a Demo 02 (registra o bucket no Lake Formation, modo só-LF por
padrão):
```cmd
aws cloudformation deploy --template-file infra\lakeformation-demo.yaml ^
  --stack-name aws-class-lakeformation-demo --capabilities CAPABILITY_NAMED_IAM ^
  --region us-east-1 ^
  --parameter-overrides DeployerPrincipalArn=arn:aws:iam::<ACCOUNT_ID>:user/<SEU_USUARIO>
```

Agora switch role para o `raw-data-engineer` da Demo 01 e repita a consulta:
```sql
SELECT * FROM aws_class_datalake.raw_raw LIMIT 10;
```
**Falha** com:
```
Insufficient permissions ... not authorized to perform: lakeformation:GetDataAccess
```

### O que explicar
Ao registrar a location, o Lake Formation assumiu o controle do acesso aos dados.
O papel da Demo 01 já não lê por IAM+S3; agora tudo passa pelo Lake Formation, e
como esse papel não tem grants de LF, o acesso é negado.

> **Registrar no Lake Formation mudou quem manda sobre os dados.**

---

## FASE 3 — Passar para HÍBRIDO: a Demo 01 volta a funcionar e os dois convivem

Execute o script de modo híbrido:
```powershell
.\scripts\powershell\enable-hybrid.ps1   # Windows
```
```bash
./scripts/bash/enable-hybrid.sh          # Linux/macOS/Git Bash
```
(faz deregister + register com `--hybrid-access-enabled`; no final imprime o
estado e deve mostrar `HybridAccessEnabled = True`)

Dê alguns segundos de propagação. Depois:

1. Switch role para o `raw-data-engineer` (Demo 01) e repita:
   ```sql
   SELECT * FROM aws_class_datalake.raw_raw LIMIT 10;   -- VOLTA a funcionar (IAM)
   ```
2. Switch role para os papéis da Demo 02 e verifique que **também** funcionam por
   grants de LF (ver `sql/10-named-resource.sql` e `sql/20-lftags.sql`).

### O que explicar
Em modo híbrido, o Lake Formation deixa que **IAM+S3 continue autorizando** os
principals que não têm grant de LF, enquanto aplica suas permissões de
granularidade fina aos que têm. Os dois modelos convivem sobre a mesma location. É
o padrão para **migrar gradualmente** para o Lake Formation sem cortar o acesso
existente.

---

## Voltar atrás (para repetir a demo)

Para voltar ao modo só-LF (e mostrar de novo que "quebra"):
```powershell
.\scripts\powershell\disable-hybrid.ps1   # Windows
```
```bash
./scripts/bash/disable-hybrid.sh          # Linux/macOS/Git Bash
```

Você pode alternar `enable-hybrid` / `disable-hybrid` quantas vezes quiser; cada um
imprime o estado resultante.

---

## Verificar o modo atual a qualquer momento

```cmd
aws lakeformation describe-resource ^
  --resource-arn arn:aws:s3:::aws-class-datalake-<ACCOUNT_ID>-us-east-1 ^
  --region us-east-1 --query "ResourceInfo.{Hybrid:HybridAccessEnabled,Role:RoleArn}" --output table
```
