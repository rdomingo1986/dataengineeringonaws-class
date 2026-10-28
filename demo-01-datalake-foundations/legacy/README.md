# Legacy — versão com AWS Lambda (substituída por Glue jobs)

Esta pasta preserva a **primeira versão** das transformações da Demo 01,
implementadas como **funções Lambda** disparadas por notificações de evento do
S3.

A demo foi migrada para **AWS Glue (PySpark)** com **Amazon EventBridge** como
mecanismo de encadeamento (S3 → EventBridge → Glue job). O código Lambda fica
aqui apenas como **referência didática**, para contrastar as duas abordagens:

| Aspecto            | Lambda (legacy)                   | Glue PySpark (atual)               |
|--------------------|-----------------------------------|------------------------------------|
| Processamento      | Função serverless, Python         | Job Spark gerenciado (DPU)         |
| Disparo pelo S3    | Notificação S3 → Lambda direta    | S3 → EventBridge → Glue job        |
| Escala de dados    | Objetos pequenos / médios         | Grandes volumes (distribuído)      |
| Custo              | Muito baixo por invocação         | Maior (DPU-hora, mín. faturável)   |

> Este código **NÃO é implantado** pelo template atual (`infra/datalake-demo.yaml`).
> Os scripts ativos estão em `../src/glue/`.
