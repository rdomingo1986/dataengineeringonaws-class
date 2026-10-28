"""
Lambda 2 — cleaned -> curated  (demo do data lake da plataforma de cursos online)

Disparada por uma notificacao de evento do S3 quando um objeto e criado sob
o prefixo `cleaned/student-events/`.

Responsabilidade: ENRIQUECIMENTO e preparacao para analitica.
  - Deriva metricas de engagement por evento (minutos de estudo, flags).
  - Classifica o engagement (none/low/medium/high) conforme a duracao.
  - Faz hash do CPF (dado sensivel) -> `cpf_hash` e descarta o CPF em claro.
  - Adiciona colunas de linhagem (processing_ts) e extrai o pais da region.
  - Escreve PARTICIONADO por `event_date=YYYY-MM-DD` em `curated/student-engagement/`.

Colunas pensadas para a Demo 02 (Lake Formation):
  - `student_email`  -> column-level security
  - `cpf_hash`       -> column-level security
  - `region`         -> row-level security / LF-Tags (p. ex. somente BR-SP)

Saida: JSON Lines. Nao requer dependencias externas (boto3 + stdlib).
"""

import hashlib
import json
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3

_s3 = None


def _client():
    """Cliente S3 preguicoso: evita tocar a AWS ao importar o modulo (testes)."""
    global _s3
    if _s3 is None:
        _s3 = boto3.client("s3")
    return _s3


CURATED_PREFIX = os.environ.get("CURATED_PREFIX", "curated/student-engagement/")
CPF_SALT = os.environ.get("CPF_SALT", "aws-class-demo-salt")

# Eventos que representam atividade de aprendizado efetiva
LEARNING_EVENTS = {"lesson_completed", "video_watched", "quiz_submitted"}


def _hash_cpf(cpf):
    if not cpf:
        return None
    digits = "".join(ch for ch in str(cpf) if ch.isdigit())
    if not digits:
        return None
    return hashlib.sha256((CPF_SALT + digits).encode("utf-8")).hexdigest()


def _engagement_level(minutes, event_type):
    if event_type == "login" or minutes <= 0:
        return "none"
    if minutes < 10:
        return "low"
    if minutes < 20:
        return "medium"
    return "high"


def _enrich(rec):
    duration = rec.get("duration_seconds") or 0
    minutes = round(duration / 60.0, 2)
    event_type = rec.get("event_type")
    region = rec.get("region") or ""
    country = region.split("-")[0] if "-" in region else region or None

    return {
        "event_id": rec.get("event_id"),
        "student_id": rec.get("student_id"),
        "student_name": rec.get("student_name"),
        "student_email": rec.get("student_email"),   # sensivel -> LF demo 2
        "cpf_hash": _hash_cpf(rec.get("cpf")),        # sensivel -> LF demo 2
        "course": rec.get("course"),
        "event_type": event_type,
        "event_ts": rec.get("event_ts"),
        "study_minutes": minutes,
        "is_learning_event": event_type in LEARNING_EVENTS,
        "is_completed": event_type == "lesson_completed",
        "score": rec.get("score"),
        "engagement_level": _engagement_level(minutes, event_type),
        "country": country,
        "region": rec.get("region"),                 # sensivel -> LF demo 2
        "device": rec.get("device"),
        "event_date": rec.get("event_date"),
        "processing_ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def _load_records(body_bytes):
    """Suporta JSON Lines (saida da Lambda 1) ou array JSON."""
    text = body_bytes.decode("utf-8").strip()
    if not text:
        return []
    if text[0] == "[":
        return json.loads(text)
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def handler(event, context):
    dest_bucket = os.environ.get("DATA_BUCKET")
    processed = 0
    written = 0

    for record in event.get("Records", []):
        src_bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        print(f"[cleaned->curated] processando s3://{src_bucket}/{key}")

        obj = _client().get_object(Bucket=src_bucket, Key=key)
        records = _load_records(obj["Body"].read())

        # Agrupar por event_date para escrever na particao correta
        by_date = {}
        for rec in records:
            processed += 1
            enriched = _enrich(rec)
            event_date = enriched.get("event_date")
            if not event_date:
                continue
            by_date.setdefault(event_date, []).append(enriched)

        base = os.path.basename(key).rsplit(".", 1)[0]
        target_bucket = dest_bucket or src_bucket

        for event_date, rows in by_date.items():
            payload = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows)
            out_key = (
                f"{CURATED_PREFIX}event_date={event_date}/{base}.jsonl"
            )
            _client().put_object(
                Bucket=target_bucket,
                Key=out_key,
                Body=payload.encode("utf-8"),
                ContentType="application/json",
            )
            written += len(rows)
            print(f"[cleaned->curated] escrito s3://{target_bucket}/{out_key} "
                  f"({len(rows)} registros)")

    return {"processed": processed, "written": written}
