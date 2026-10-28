"""
Lambda 1 — raw -> cleaned  (demo do data lake da plataforma de cursos online)

Disparada por uma notificacao de evento do S3 quando um objeto e criado sob
o prefixo `raw/student-events/`.

Responsabilidade: PRIMEIRA LIMPEZA de dados brutos "sujos".
  - Normaliza datas para ISO-8601 (aceita multiplos formatos de entrada).
  - Normaliza strings: trim, colapsa espacos, padroniza maiusculas.
  - Normaliza nomes de curso e event_type para um vocabulario controlado.
  - Tipa numeros (duration_seconds, score) descartando valores invalidos.
  - Remove registros lixo (sem student_id ou sem data valida).
  - Remove duplicatas exatas por event_id.
  - Normaliza email para minusculas e region para MAIUSCULAS.

Saida: JSON Lines (um objeto por linha) em `cleaned/student-events/`.
Nao requer dependencias externas: apenas boto3 (incluido no runtime) e stdlib.
"""

import json
import os
import re
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


CLEANED_PREFIX = os.environ.get("CLEANED_PREFIX", "cleaned/student-events/")

# Vocabulario controlado de tipos de evento
EVENT_TYPE_MAP = {
    "login": "login",
    "lesson_completed": "lesson_completed",
    "video_watched": "video_watched",
    "quiz_submitted": "quiz_submitted",
}

# Formatos de data aceitos na entrada bruta
DATE_FORMATS = [
    "%Y-%m-%dT%H:%M:%SZ",   # 2026-03-01T10:05:00Z
    "%Y-%m-%d %H:%M:%S",    # 2026-03-01 08:15:32
    "%Y-%m-%d %H:%M",       # 2026-03-01 08:15
    "%d/%m/%Y %H:%M:%S",    # 01/03/2026 09:40:00
    "%d/%m/%Y %H:%M",       # 01/03/2026 09:40
    "%Y-%m-%d",             # 2026-03-01
    "%d/%m/%Y",             # 01/03/2026
]


def _clean_text(value):
    """Trim + colapsa espacos internos. Retorna None se ficar vazio."""
    if value is None:
        return None
    text = re.sub(r"\s+", " ", str(value)).strip()
    return text or None


def _title_course(value):
    """Normaliza o nome do curso para Title Case consistente."""
    text = _clean_text(value)
    if text is None:
        return None
    # Title case respeitando acentos; mantem siglas conhecidas em maiuscula
    titled = text.title()
    # Correcoes de siglas apos title()
    titled = re.sub(r"\bAws\b", "AWS", titled)
    titled = re.sub(r"\bSql\b", "SQL", titled)
    return titled


def _normalize_event_type(value):
    text = _clean_text(value)
    if text is None:
        return None
    key = text.lower()
    return EVENT_TYPE_MAP.get(key, key)


def _parse_timestamp(value):
    """Retorna (iso_ts, event_date) ou (None, None) se nao for parseavel."""
    text = _clean_text(value)
    if text is None:
        return None, None
    for fmt in DATE_FORMATS:
        try:
            dt = datetime.strptime(text, fmt)
            # Assumir UTC se nao houver tz; normalizar
            dt = dt.replace(tzinfo=timezone.utc)
            return dt.strftime("%Y-%m-%dT%H:%M:%SZ"), dt.strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None, None


def _to_int(value):
    try:
        if value is None:
            return None
        return int(float(str(value).strip()))
    except (ValueError, TypeError):
        return None


def _to_float(value):
    try:
        if value is None:
            return None
        return float(str(value).strip())
    except (ValueError, TypeError):
        return None


def _normalize_region(value):
    text = _clean_text(value)
    if text is None:
        return None
    return text.upper()


def _clean_record(raw):
    """Aplica todas as regras de limpeza a um registro. Retorna dict ou None."""
    student_id = _clean_text(raw.get("student_id"))
    iso_ts, event_date = _parse_timestamp(raw.get("event_ts"))

    # Descartar lixo: sem estudante ou sem data valida nao serve
    if not student_id or not iso_ts:
        return None

    return {
        "event_id": _clean_text(raw.get("event_id")),
        "student_id": student_id.upper(),
        "student_name": _clean_text(raw.get("student_name")),
        "student_email": (_clean_text(raw.get("student_email")) or "").lower() or None,
        "cpf": _clean_text(raw.get("cpf")),
        "course": _title_course(raw.get("course")),
        "event_type": _normalize_event_type(raw.get("event_type")),
        "event_ts": iso_ts,
        "event_date": event_date,
        "duration_seconds": _to_int(raw.get("duration_seconds")),
        "score": _to_float(raw.get("score")),
        "region": _normalize_region(raw.get("region")),
        "device": (_clean_text(raw.get("device")) or "").lower() or None,
    }


def _load_records(body_bytes):
    """Suporta um array JSON ou JSON Lines no objeto raw."""
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
        # Os eventos S3 trazem a key url-encoded
        key = unquote_plus(record["s3"]["object"]["key"])

        print(f"[raw->cleaned] processando s3://{src_bucket}/{key}")
        obj = _client().get_object(Bucket=src_bucket, Key=key)
        raw_records = _load_records(obj["Body"].read())

        cleaned = []
        seen_event_ids = set()
        for raw in raw_records:
            processed += 1
            rec = _clean_record(raw)
            if rec is None:
                continue
            # Dedup exato por event_id
            eid = rec.get("event_id")
            if eid and eid in seen_event_ids:
                continue
            if eid:
                seen_event_ids.add(eid)
            cleaned.append(rec)

        if not cleaned:
            print(f"[raw->cleaned] sem registros validos em {key}")
            continue

        # JSON Lines de saida
        payload = "\n".join(json.dumps(r, ensure_ascii=False) for r in cleaned)

        base = os.path.basename(key).rsplit(".", 1)[0]
        out_key = f"{CLEANED_PREFIX}{base}.jsonl"
        target_bucket = dest_bucket or src_bucket
        _client().put_object(
            Bucket=target_bucket,
            Key=out_key,
            Body=payload.encode("utf-8"),
            ContentType="application/json",
        )
        written += len(cleaned)
        print(f"[raw->cleaned] escrito s3://{target_bucket}/{out_key} "
              f"({len(cleaned)} registros)")

    return {"processed": processed, "written": written}
