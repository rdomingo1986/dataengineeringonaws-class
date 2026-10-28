# Runbook — Demo 06: Streaming Analytics

Guia operacional passo a passo para implantar, operar e remover esta demo.
Cada comando é mostrado em **bash** (Linux/macOS/Git Bash) e **PowerShell**
(Windows). Use a variante do seu terminal.

> **Fonte da verdade:** este runbook. Os scripts em `scripts/bash/` e
> `scripts/powershell/` automatizam exatamente estes mesmos passos.

> **Demo autônoma:** não depende de nenhuma outra demo e não publica Exports.

---

## Convenções e nomes de recursos

| Recurso              | Nome / valor                                            |
|----------------------|---------------------------------------------------------|
| Stack CloudFormation | `aws-class-streaming-demo`                             |
| Kinesis Data Stream  | `aws-class-events-stream` (ON_DEMAND)                 |
| Firehose             | `aws-class-events-to-s3`                              |
| Lambda consumidora   | `aws-class-stream-consumer`                           |
| Dashboard CloudWatch | `aws-class-streaming`                                 |
| Namespace de métricas| `AwsClass/Streaming`                                  |
| Bucket de entrega    | `aws-class-streaming-<ACCOUNT_ID>-<REGION>`           |
| Região               | `us-east-1` (ajuste se necessário)                     |

> **Nota sobre shells:** um `.sh` criado no Windows pode ter quebras CRLF e falhar
> no Linux. Em Linux/macOS garanta quebras LF; no Windows prefira os `.ps1`.

---

## 0. Pré-requisitos (verificar ANTES de começar)

- bash / PowerShell (igual)
  ```
  aws sts get-caller-identity --query Account --output text
  aws --version
  ```

**Checklist:**
- [ ] AWS CLI v2; credenciais para CloudFormation, Kinesis, Firehose, Lambda,
      CloudWatch, IAM e S3.
- [ ] Python 3 + boto3 para rodar o produtor (`pip install boto3`).
- [ ] Capacidade de criar named IAM roles (`CAPABILITY_NAMED_IAM`).

> **Sem dependências de entrada.** Esta demo cria seu próprio stream, bucket e
> dashboard, independentes das outras demos.

---

## 1. Implantar o stack

Empacota a Lambda consumidora (SAM package) e implanta: stream Kinesis, bucket,
Firehose, Lambda (com event source mapping) e dashboard do CloudWatch.

- bash
  ```bash
  ./scripts/bash/deploy.sh
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\deploy.ps1
  ```

**Verificação:**
```
aws cloudformation describe-stacks --stack-name aws-class-streaming-demo --region us-east-1 --query "Stacks[0].StackStatus" --output text
```

---

## 2. Abrir o dashboard do CloudWatch

Nos Outputs do stack está `DashboardUrl`. Abra-o (ou vá a CloudWatch →
Dashboards → `aws-class-streaming`). No início estará vazio.

---

## 3. Iniciar o produtor (simular o stream)

Envia eventos ao Kinesis de forma contínua. Deixe rodando e observe o dashboard
(as linhas aparecem em ~1-2 min).

- bash
  ```bash
  ./scripts/bash/run-producer.sh 10 300   # 10 eventos/seg durante 5 min
  ./scripts/bash/run-producer.sh          # 5 eventos/seg, infinito (Ctrl+C para parar)
  ```
- PowerShell
  ```powershell
  .\scripts\powershell\run-producer.ps1 10 300
  .\scripts\powershell\run-producer.ps1
  ```

---

## 4. Consultar o acumulado no Athena (ramificação de ingestão)

O Firehose entrega ao S3 a cada ~60s. Depois de alguns minutos, no Athena:
crie a tabela externa (query 1 de `sql/queries.sql`, ajuste o bucket) e rode as
consultas de contagem por tipo/curso/região.

---

## 5. Teardown (remover tudo)

> **Pare o produtor** (Ctrl+C) antes do teardown.

1. Esvaziar o bucket de entrega (o CloudFormation não apaga buckets com objetos):
   ```
   aws s3 rm s3://aws-class-streaming-<ACCOUNT_ID>-us-east-1 --recursive
   ```
2. Apagar o stack:
   ```
   aws cloudformation delete-stack --stack-name aws-class-streaming-demo --region us-east-1
   aws cloudformation wait stack-delete-complete --stack-name aws-class-streaming-demo --region us-east-1
   ```
3. (Opcional) Se criou a tabela externa no Athena, remova-a:
   ```
   aws glue delete-table --database-name default --name streaming_events --region us-east-1
   ```

---

## Dependências e integração com outras demos

- **Entrada:** nenhuma. Totalmente autônoma.
- **Saída / exports:** nenhuma.
- **Bucket compartilhado:** usa o bucket de artefatos
  `aws-class-cfn-artifacts-<ACCOUNT_ID>-<REGION>` apenas como destino do SAM package
  (código da Lambda). O bucket de dados do streaming é próprio e exclusivo desta
  demo (`aws-class-streaming-*`).
- **Conflitos de nome:** o prefixo `aws-class-events-*` / `aws-class-streaming`
  é exclusivo desta demo; não colide com as demais.
