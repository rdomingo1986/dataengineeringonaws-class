"""
Lambda consumidora do stream (plataforma de cursos online) -> metricas no CloudWatch.

E invocada por um Event Source Mapping do Kinesis: recebe lotes de registros do
stream, os decodifica e publica METRICAS PERSONALIZADAS no CloudWatch
(PutMetricData) para visualizar o streaming em tempo (quase) real em um
dashboard.

Metricas publicadas no namespace 'AwsClass/Streaming':
  - EventCount           dimensao: EventType   (eventos por tipo)
  - EventCount           dimensao: Course       (eventos por curso)
  - EventsTotal          (contagem total do lote)

Nao requer dependencias externas: boto3 (no runtime) + stdlib.
"""

import base64
import json
from collections import Counter

import boto3

cloudwatch = boto3.client("cloudwatch")
NAMESPACE = "AwsClass/Streaming"


def _metric(name, value, dim_name=None, dim_value=None):
    m = {"MetricName": name, "Value": value, "Unit": "Count"}
    if dim_name:
        m["Dimensions"] = [{"Name": dim_name, "Value": dim_value}]
    return m


def handler(event, context):
    records = event.get("Records", [])
    by_type = Counter()
    by_course = Counter()
    total = 0

    for r in records:
        try:
            raw = base64.b64decode(r["kinesis"]["data"])
            # O produtor envia um objeto JSON por registro (com \n no final)
            ev = json.loads(raw.decode("utf-8").strip())
        except Exception as e:
            print("registro nao parseavel:", e)
            continue
        total += 1
        by_type[ev.get("event_type", "unknown")] += 1
        by_course[ev.get("course", "unknown")] += 1

    if total == 0:
        return {"processed": 0}

    # Montar o lote de metricas (o CloudWatch aceita ate 1000 por chamada;
    # aqui sao poucas, nao e preciso paginar).
    metric_data = [_metric("EventsTotal", total)]
    for etype, n in by_type.items():
        metric_data.append(_metric("EventCount", n, "EventType", etype))
    for course, n in by_course.items():
        metric_data.append(_metric("EventCount", n, "Course", course))

    cloudwatch.put_metric_data(Namespace=NAMESPACE, MetricData=metric_data)
    print(f"[consumer] lote processado: {total} eventos, "
          f"{len(by_type)} tipos, {len(by_course)} cursos")
    return {"processed": total}
