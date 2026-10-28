"""
Lambda disparadora (glue trigger) — data lake da plataforma de cursos online.

O EventBridge nao pode invocar um Glue job diretamente, entao esta Lambda
minima recebe o evento do S3 (via EventBridge) e inicia o Glue job
correspondente conforme o prefixo do objeto criado:

  raw/      -> job raw->cleaned
  cleaned/  -> job cleaned->curated

O processamento pesado (as transformacoes) vive nos Glue jobs PySpark; esta
funcao apenas "aperta o botao de start".
"""

import os

import boto3

glue = boto3.client("glue")

RAW_TO_CLEANED_JOB = os.environ["RAW_TO_CLEANED_JOB"]
CLEANED_TO_CURATED_JOB = os.environ["CLEANED_TO_CURATED_JOB"]


def handler(event, context):
    # Evento do S3 via EventBridge: a key esta em detail.object.key
    detail = event.get("detail", {})
    key = detail.get("object", {}).get("key", "")
    print(f"[trigger] objeto criado: {key}")

    if key.startswith("raw/"):
        job = RAW_TO_CLEANED_JOB
    elif key.startswith("cleaned/"):
        job = CLEANED_TO_CURATED_JOB
    else:
        print(f"[trigger] prefixo nao tratado, ignorado: {key}")
        return {"started": None, "key": key}

    run = glue.start_job_run(JobName=job)
    print(f"[trigger] job {job} iniciado, run {run['JobRunId']}")
    return {"started": job, "runId": run["JobRunId"], "key": key}
