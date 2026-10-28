"""
Glue job — curated -> modelo dimensional (plataforma de cursos online, ramificacao data warehouse).

Le a zona curada do data lake (Demo 01) e constroi um MODELO ESTRELA para o
Amazon Redshift:
  - dim_student     (uma linha por estudante)
  - dim_course      (uma linha por curso)
  - fact_engagement (uma linha por evento, com metricas e chaves estrangeiras)

Escreve cada tabela como CSV no S3, em um prefixo de staging, pronto para que o
Redshift as carregue com COPY (via Redshift Data API, orquestrado pelo Step
Functions).

Saida CSV (nao JSON) porque o COPY do Redshift e direto e eficiente com CSV, e e
o formato canonico discutido no modulo.
"""

import sys

from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "data_bucket", "stage_prefix"])
DATA_BUCKET = args["data_bucket"]
STAGE_PREFIX = args["stage_prefix"].strip("/")

CURATED_PATH = f"s3://{DATA_BUCKET}/curated/student-engagement/"
STAGE_BASE = f"s3://{DATA_BUCKET}/{STAGE_PREFIX}"

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
print(f"[curated->dim] lendo {CURATED_PATH}")

curated = spark.read.json(CURATED_PATH)

# Garantir colunas esperadas (o Spark omite colunas sempre-null ao inferir).
EXPECTED = {
    "event_id": "string", "student_id": "string", "student_name": "string",
    "student_email": "string", "course": "string", "event_type": "string",
    "event_ts": "string", "event_date": "string", "study_minutes": "double",
    "score": "double", "engagement_level": "string", "is_completed": "boolean",
    "region": "string", "country": "string",
}
for col, typ in EXPECTED.items():
    if col not in curated.columns:
        curated = curated.withColumn(col, F.lit(None).cast(typ))


def write_csv(df, name):
    """Escreve uma tabela como um unico CSV (sem header) em staging/<name>/."""
    out = f"{STAGE_BASE}/{name}/"
    print(f"[curated->dim] escrevendo {name} -> {out}")
    (
        df.coalesce(1)
        .write
        .mode("overwrite")
        .option("header", "false")
        .csv(out)
    )


# ---------------------------------------------------------------------------
# dim_student: uma linha por estudante (ultimo valor conhecido de seus atributos)
# ---------------------------------------------------------------------------
dim_student = (
    curated
    .where(F.col("student_id").isNotNull())
    .groupBy("student_id")
    .agg(
        F.max("student_name").alias("student_name"),
        F.max("student_email").alias("student_email"),
        F.max("region").alias("region"),
        F.max("country").alias("country"),
    )
    .select("student_id", "student_name", "student_email", "region", "country")
)
write_csv(dim_student, "dim_student")

# ---------------------------------------------------------------------------
# dim_course: uma linha por curso. course_id = slug estavel do nome.
# ---------------------------------------------------------------------------
course_id = F.lower(F.regexp_replace(F.col("course"), r"\s+", "_"))
dim_course = (
    curated
    .where(F.col("course").isNotNull())
    .select(course_id.alias("course_id"), F.col("course").alias("course_name"))
    .dropDuplicates(["course_id"])
)
write_csv(dim_course, "dim_course")

# ---------------------------------------------------------------------------
# fact_engagement: uma linha por evento, com FKs para as dimensoes.
# ---------------------------------------------------------------------------
fact = (
    curated
    .where(F.col("event_id").isNotNull())
    .select(
        F.col("event_id"),
        F.col("student_id"),
        F.lower(F.regexp_replace(F.col("course"), r"\s+", "_")).alias("course_id"),
        F.col("event_type"),
        F.col("event_ts"),
        F.col("event_date"),
        F.col("study_minutes"),
        F.col("score"),
        F.col("engagement_level"),
        F.col("is_completed"),
    )
)
write_csv(fact, "fact_engagement")

print("[curated->dim] modelo dimensional escrito no staging")
