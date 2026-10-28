"""
Glue job 1 — raw -> cleaned  (data lake da plataforma de cursos online, PySpark)

Disparado pelo EventBridge quando um objeto e criado sob `raw/student-events/`.

Design: o job reprocessa TODO o prefixo `raw/student-events/` a cada
execucao (nao um arquivo pontual). Assim o EventBridge so precisa INICIAR o job
(sem passar argumentos dinamicos), o que evita Lambdas de cola e mantem a
arquitetura simples e declarativa. A escrita em modo overwrite torna o job
idempotente: reexecuta-lo nao duplica dados.

PRIMEIRA LIMPEZA de dados brutos "sujos":
  - Normaliza datas para ISO-8601 (aceita varios formatos de entrada).
  - Limpa strings (trim, colapsa espacos) e padroniza cursos / event_type.
  - Tipa numeros (duration_seconds, score); descarta valores invalidos.
  - Descarta registros lixo (sem student_id ou sem data valida).
  - Remove duplicatas exatas por event_id.
  - Normaliza email para minusculas e region para MAIUSCULAS.

Saida: JSON Lines em `cleaned/student-events/` (formato que o Athena le direto).
"""

import sys

from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "data_bucket"])
DATA_BUCKET = args["data_bucket"]

INPUT_PATH = f"s3://{DATA_BUCKET}/raw/student-events/"
OUTPUT_PATH = f"s3://{DATA_BUCKET}/cleaned/student-events/"

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
print(f"[raw->cleaned] lendo {INPUT_PATH}")

# ---------------------------------------------------------------------------
# 1) Ler o JSON bruto em formato JSON Lines (um objeto por linha).
#    recursiveFileLookup permite ler objetos em subpastas
#    (raw/student-events/YYYY/MM/DD/...).
# ---------------------------------------------------------------------------
raw = (
    spark.read
    # SEM multiLine: os dados brutos sao JSON Lines (um objeto por linha).
    # multiLine=true quebra o JSON Lines (Spark espera um unico doc por arquivo).
    .option("recursiveFileLookup", "true")
    .json(INPUT_PATH)
)

# O Spark omite do esquema inferido qualquer campo que seja sempre null no
# lote. Garantimos que todas as colunas esperadas existam (como null se
# faltarem) para que o select nao falhe com lotes incompletos.
EXPECTED_RAW_COLUMNS = [
    "event_id", "student_id", "student_name", "student_email", "cpf",
    "course", "event_type", "event_ts", "duration_seconds", "score",
    "region", "device",
]
for col_name in EXPECTED_RAW_COLUMNS:
    if col_name not in raw.columns:
        print(f"[raw->cleaned] coluna ausente '{col_name}', criada como null")
        raw = raw.withColumn(col_name, F.lit(None).cast("string"))

# ---------------------------------------------------------------------------
# 2) Normalizar datas: testar varios formatos e ficar com o primeiro que
#    der parse. Dai derivamos event_ts (ISO) e event_date (para particionar).
# ---------------------------------------------------------------------------
DATE_FORMATS = [
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd HH:mm",
    "dd/MM/yyyy HH:mm:ss",
    "dd/MM/yyyy HH:mm",
    "yyyy-MM-dd",
    "dd/MM/yyyy",
]
ts = F.coalesce(*[F.to_timestamp(F.col("event_ts"), fmt) for fmt in DATE_FORMATS])


def clean_text(col):
    """Trim + colapsa espacos internos; string vazia -> NULL."""
    collapsed = F.trim(F.regexp_replace(col.cast("string"), r"\s+", " "))
    return F.when(collapsed == "", None).otherwise(collapsed)


# ---------------------------------------------------------------------------
# 3) Aplicar as regras de limpeza em um unico select legivel.
# ---------------------------------------------------------------------------
cleaned = (
    raw
    .withColumn("_ts", ts)
    .withColumn("_student_id", clean_text(F.col("student_id")))
    # descartar lixo: sem student_id ou sem data valida
    .where(F.col("_student_id").isNotNull() & F.col("_ts").isNotNull())
    .select(
        clean_text(F.col("event_id")).alias("event_id"),
        F.upper(F.col("_student_id")).alias("student_id"),
        clean_text(F.col("student_name")).alias("student_name"),
        F.lower(clean_text(F.col("student_email"))).alias("student_email"),
        clean_text(F.col("cpf")).alias("cpf"),
        # curso: Title Case + siglas conhecidas em maiuscula
        F.regexp_replace(
            F.regexp_replace(
                F.initcap(clean_text(F.col("course"))), r"\bAws\b", "AWS"
            ),
            r"\bSql\b", "SQL",
        ).alias("course"),
        F.lower(clean_text(F.col("event_type"))).alias("event_type"),
        F.date_format(F.col("_ts"), "yyyy-MM-dd'T'HH:mm:ss'Z'").alias("event_ts"),
        F.date_format(F.col("_ts"), "yyyy-MM-dd").alias("event_date"),
        # numeros: cast seguro (nao numerico -> NULL)
        F.col("duration_seconds").cast("int").alias("duration_seconds"),
        F.col("score").cast("double").alias("score"),
        F.upper(clean_text(F.col("region"))).alias("region"),
        F.lower(clean_text(F.col("device"))).alias("device"),
    )
    # dedup exato por event_id
    .dropDuplicates(["event_id"])
)

print(f"[raw->cleaned] registros limpos: {cleaned.count()}")

# ---------------------------------------------------------------------------
# 4) Escrever JSON Lines em cleaned. overwrite = idempotente (reprocessa todo o
#    prefixo raw e substitui a saida). coalesce(1) = um arquivo (dados de demo).
# ---------------------------------------------------------------------------
cleaned.coalesce(1).write.mode("overwrite").json(OUTPUT_PATH)
print(f"[raw->cleaned] escrito em {OUTPUT_PATH}")
