"""
Produtor de eventos de streaming (plataforma de cursos online) -> Kinesis Data Streams.

Simula o stream em tempo real de eventos da plataforma de aprendizagem:
reproducao de video (play/pause/seek), quizzes, navegacao. Envia eventos de
forma continua para um stream do Kinesis para a demo de streaming analytics.

Uso:
    python produce_events.py [--stream NOME] [--region us-east-1] [--rate 5] [--seconds 300]

  --stream   nome do Kinesis Data Stream (default: aws-class-events-stream)
  --region   regiao AWS (default: us-east-1)
  --rate     eventos por segundo aprox. (default: 5)
  --seconds  duracao total; 0 = infinito ate Ctrl+C (default: 0)

Requer boto3 e credenciais AWS configuradas.
"""

import argparse
import json
import random
import time
import uuid
from datetime import datetime, timezone

import boto3

COURSES = [
    "Python para Dados", "Fundamentos de AWS", "SQL Avancado",
    "Machine Learning", "Engenharia de Dados", "Visualizacao de Dados",
]
EVENT_TYPES = ["video_play", "video_pause", "video_seek", "quiz_submitted", "page_view"]
REGIONS = ["BR-SP", "BR-RJ", "BR-MG", "BR-RS", "BR-PR", "BR-BA"]
DEVICES = ["mobile", "desktop", "tablet"]


def make_event():
    etype = random.choice(EVENT_TYPES)
    ev = {
        "event_id": str(uuid.uuid4()),
        "event_ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "student_id": f"STU-{random.randint(1000, 1200)}",
        "course": random.choice(COURSES),
        "event_type": etype,
        "region": random.choice(REGIONS),
        "device": random.choice(DEVICES),
    }
    # Campos especificos conforme o tipo de evento
    if etype in ("video_play", "video_pause", "video_seek"):
        ev["video_position_sec"] = random.randint(0, 1800)
    if etype == "quiz_submitted":
        ev["score"] = round(random.uniform(0, 10), 1)
    return ev


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--stream", default="aws-class-events-stream")
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--rate", type=float, default=5.0)
    p.add_argument("--seconds", type=int, default=0)
    args = p.parse_args()

    kinesis = boto3.client("kinesis", region_name=args.region)
    print(f"Enviando ~{args.rate} eventos/seg para {args.stream} "
          f"({'infinito' if args.seconds == 0 else str(args.seconds)+'s'}). Ctrl+C para parar.")

    start = time.time()
    sent = 0
    interval = 1.0 / args.rate if args.rate > 0 else 0.2
    try:
        while args.seconds == 0 or (time.time() - start) < args.seconds:
            ev = make_event()
            kinesis.put_record(
                StreamName=args.stream,
                Data=(json.dumps(ev) + "\n").encode("utf-8"),
                PartitionKey=ev["student_id"],
            )
            sent += 1
            if sent % 20 == 0:
                print(f"  enviados: {sent}  (ultimo: {ev['event_type']} / {ev['course']})")
            time.sleep(interval)
    except KeyboardInterrupt:
        pass
    print(f"Total enviados: {sent}")


if __name__ == "__main__":
    main()
