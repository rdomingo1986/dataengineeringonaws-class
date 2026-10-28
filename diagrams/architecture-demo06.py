"""
Gerador do diagrama de arquitetura da Demo 06 — Streaming Analytics.

Usa a biblioteca `diagrams` (mingrammer), que traz os ICONES OFICIAIS da AWS.
Renderiza com Graphviz.

Pré-requisitos:
    pip install diagrams
    Graphviz instalado e no PATH (comando `dot`).

Uso:
    python diagrams/architecture-demo06.py
    -> gera  diagrams/arquitetura-demo06.png

Código visual das setas (mesmo padrão do diagrama das Demos 01–05):
  - cinza sólida   -> fluxo de dados / processamento
  - laranja sólida -> ingestão em tempo real (eventos que chegam ao stream)
  - azul pontilhada  -> catalogação / metadados (schema sobre os dados no S3)
"""

from diagrams import Diagram, Cluster, Edge, Node
from diagrams.aws.analytics import (
    KinesisDataStreams,
    KinesisDataFirehose,
    Athena,
)
from diagrams.aws.compute import Lambda
from diagrams.aws.storage import S3
from diagrams.aws.management import Cloudwatch
from diagrams.aws.general import Users

OUTPUT = "diagrams/arquitetura-demo06"

# --- Código visual das setas (consistente com o diagrama 01–05) -----------
DATA = {"color": "gray40"}                                   # fluxo de dados
EVENT = {"color": "darkorange", "penwidth": "2.0"}           # ingestão em tempo real
CATALOG = {"color": "royalblue", "style": "dashed"}          # catalogação/metadados

graph_attr = {
    "fontsize": "20",
    "labelloc": "t",
    "pad": "0.6",
    "nodesep": "0.8",
    "ranksep": "1.2",
    "splines": "spline",
}

with Diagram(
    "Data Engineering on AWS — Demo 06: Streaming Analytics",
    filename=OUTPUT,
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    producer = Users("Produtor\n(eventos simulados)")

    with Cluster("Ingestão em tempo real"):
        stream = KinesisDataStreams("Kinesis Data Streams\n(aws-class-events-stream)")

    # Produtor envia eventos ao stream (tempo real)
    producer >> Edge(label="put_record", **EVENT) >> stream

    # --- Ramificação 1: ingestão analítica (Firehose -> S3 -> Athena) ------
    with Cluster("Ramificação 1 — Ingestão analítica (histórico)"):
        firehose = KinesisDataFirehose("Firehose\n(micro-batches ~60s)")
        bucket = S3("S3\nevents/dt=.../")
        athena = Athena("Athena\n(análise histórica)")
        firehose >> Edge(label="entrega", **DATA) >> bucket
        bucket >> Edge(label="query", **CATALOG) >> athena

    # --- Ramificação 2: tempo real (Lambda -> CloudWatch dashboard) --------
    with Cluster("Ramificação 2 — Tempo (quase) real"):
        consumer = Lambda("Lambda consumidora\n(aws-class-stream-consumer)")
        cw = Cloudwatch("CloudWatch Dashboard\n(métricas ao vivo)")
        consumer >> Edge(label="PutMetricData", **DATA) >> cw

    # O MESMO stream alimenta as duas ramificações em paralelo
    stream >> Edge(label="source", **DATA) >> firehose
    stream >> Edge(label="event source mapping", **DATA) >> consumer

    # ---------------------------------------------------------------
    # Legenda — mostra o código visual das setas (só as linhas).
    # ---------------------------------------------------------------
    with Cluster("Legenda (código das setas)"):
        dot = {"shape": "point", "width": "0.06", "color": "gray30"}
        a1 = Node("", **dot); a2 = Node("", **dot)
        b1 = Node("", **dot); b2 = Node("", **dot)
        c1 = Node("", **dot); c2 = Node("", **dot)

        a1 >> Edge(label="  fluxo de dados / processamento", **DATA) >> a2
        b1 >> Edge(label="  ingestão em tempo real (eventos)", **EVENT) >> b2
        c1 >> Edge(label="  catalogação / metadados (schema sobre S3)", **CATALOG) >> c2

        a2 >> Edge(style="invis") >> b1
        b2 >> Edge(style="invis") >> c1
