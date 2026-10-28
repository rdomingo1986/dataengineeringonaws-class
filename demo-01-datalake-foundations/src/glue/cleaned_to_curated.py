"""
Glue job 2 — cleaned -> curated  (data lake da plataforma de cursos online, PySpark)

Disparado pelo EventBridge quando um objeto e criado sob `cleaned/student-events/`.

ENRIQUECIMENTO e preparacao para analitica:
  - Deriva study_minutes e flags (is_learning_event, is_completed).
  - Classifica o engagement (none/low/medium/high) conforme os minutos.
  - Faz hash do CPF (dado sensivel) -> cpf_hash e DESCARTA o CPF em claro.
  - Deriva country a partir de region; adiciona processing_ts (linhagem).
  - Escreve PARTICIONADO por event_date em `curated/student-engagement/`.

Colunas pensadas para a Demo 02 (Lake Formation):
  student_email, cpf_hash -> column-level ; region -> row-level / LF-Tags.

Nota de design: o job reprocessa TODO `cleaned/student-events/` e usa escrita
com particoes dinamicas em modo overwrite. Assim o resultado e idempotente
(reexecuta-lo nao duplica) e o codigo fica simples, que e o que importa para
a demo.

Saida: JSON Lines particionado, que o Athena le direto.
"""

import sys

from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "data_bucket", "cpf_salt"])
DATA_BUCKET = args["data_bucket"]
CPF_SALT = args["cpf_salt"]

INPUT_PATH = f"s3://{DATA_BUCKET}/cleaned/student-events/"
OUTPUT_PATH = f"s3://{DATA_BUCKET}/curated/student-engagement/"

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
# Particoes dinamicas: so sobrescreve as particoes que chegam.
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

print(f"[cleaned->curated] lendo {INPUT_PATH}")
cleaned = spark.read.json(INPUT_PATH)

# Ao inferir o esquema do JSON, o Spark OMITE uma coluna se em todo o lote ela
# for sempre null (p. ex. 'score' quando nenhum evento traz pontuacao). Para que
# o select nao falhe, garantimos que todas as colunas esperadas existam; as
# que faltarem sao criadas como null com o tipo adequado.
EXPECTED_COLUMNS = {
    "event_id": "string",
    "student_id": "string",
    "student_name": "string",
    "student_email": "string",
    "cpf": "string",
    "course": "string",
    "event_type": "string",
    "event_ts": "string",
    "event_date": "string",
    "duration_seconds": "int",
    "score": "double",
    "region": "string",
    "device": "string",
}
for col_name, col_type in EXPECTED_COLUMNS.items():
    if col_name not in cleaned.columns:
        print(f"[cleaned->curated] coluna ausente '{col_name}', criada como null")
        cleaned = cleaned.withColumn(col_name, F.lit(None).cast(col_type))

LEARNING_EVENTS = ["lesson_completed", "video_watched", "quiz_submitted"]

# study_minutes = duracao / 60 (minutos, 2 casas decimais)
study_minutes = F.round(F.coalesce(F.col("duration_seconds"), F.lit(0)) / 60.0, 2)

# engagement_level conforme minutos e tipo de evento
engagement_level = (
    F.when((F.col("event_type") == "login") | (study_minutes <= 0), "none")
    .when(study_minutes < 10, "low")
    .when(study_minutes < 20, "medium")
    .otherwise("high")
)

# cpf_hash = sha256(salt + digitos do cpf). O cpf em claro NAO vai para curated.
cpf_digits = F.regexp_replace(F.coalesce(F.col("cpf"), F.lit("")), r"\D", "")
cpf_hash = F.when(
    cpf_digits != "", F.sha2(F.concat(F.lit(CPF_SALT), cpf_digits), 256)
).otherwise(None)

# country = parte antes do hifen em region (BR-SP -> BR)
country = F.when(
    F.col("region").contains("-"), F.split(F.col("region"), "-").getItem(0)
).otherwise(F.col("region"))

curated = cleaned.select(
    F.col("event_id"),
    F.col("student_id"),
    F.col("student_name"),
    F.col("student_email"),                    # sensivel -> LF demo 2
    cpf_hash.alias("cpf_hash"),                # sensivel -> LF demo 2
    F.col("course"),
    F.col("event_type"),
    F.col("event_ts"),
    study_minutes.alias("study_minutes"),
    F.col("event_type").isin(LEARNING_EVENTS).alias("is_learning_event"),
    (F.col("event_type") == "lesson_completed").alias("is_completed"),
    F.col("score"),
    engagement_level.alias("engagement_level"),
    country.alias("country"),
    F.col("region"),                           # sensivel -> LF demo 2
    F.col("device"),
    F.date_format(F.current_timestamp(), "yyyy-MM-dd'T'HH:mm:ss'Z'").alias("processing_ts"),
    F.col("event_date"),                       # coluna de particao (vai no final)
)

count = curated.count()
print(f"[cleaned->curated] registros curados: {count}")

# Escrever JSON Lines particionado por event_date.
(
    curated
    .coalesce(1)
    .write
    .mode("overwrite")
    .partitionBy("event_date")
    .json(OUTPUT_PATH)
)
print(f"[cleaned->curated] escrito em {OUTPUT_PATH}")
