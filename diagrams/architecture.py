"""
Gerador do diagrama de arquitetura das Demos 01 a 05 (plataforma de cursos online).

Usa a biblioteca `diagrams` (mingrammer), que traz os ICONES OFICIAIS da AWS.
Renderiza com Graphviz.

Pré-requisitos:
    pip install diagrams
    Graphviz instalado e no PATH (comando `dot`).

Uso:
    python diagrams/architecture.py
    -> gera  diagrams/arquitetura-demos-01-05.png

Código visual das setas (ver também o cluster "Legenda" no diagrama):
  - cinza sólida   -> fluxo de dados / processamento (um passo transforma/move dados)
  - laranja sólida -> gatilho por EVENTO da AWS (ex.: Glue Job SUCCEEDED)
  - azul pontilhada  -> catalogação / metadados (schema sobre os dados no S3)
  - verde pontilhada -> governança / controle de acesso (Lake Formation)
"""

from diagrams import Diagram, Cluster, Edge, Node
from diagrams.aws.storage import S3
from diagrams.aws.analytics import (
    Glue,
    GlueCrawlers,
    GlueDataCatalog,
    Athena,
    LakeFormation,
    Redshift,
    EMR,
)
from diagrams.aws.compute import Lambda
from diagrams.aws.integration import Eventbridge, StepFunctions

# Nome do arquivo de saída (sem extensão; o formato define .png).
OUTPUT = "diagrams/arquitetura-demos-01-05"

# --- Código visual das setas (estilo semântico consistente) ---------------
DATA = {"color": "gray40"}                                   # fluxo de dados
EVENT = {"color": "darkorange", "penwidth": "2.0"}           # gatilho por evento
CATALOG = {"color": "royalblue", "style": "dashed"}          # catalogação/metadados
GOVERN = {"color": "darkgreen", "style": "dotted", "penwidth": "2.0"}  # governança

graph_attr = {
    "fontsize": "20",
    "labelloc": "t",
    "pad": "0.6",
    "nodesep": "0.7",
    "ranksep": "1.1",
    "splines": "spline",
}

with Diagram(
    "Data Engineering on AWS — Demos 01–05 (plataforma de cursos online)",
    filename=OUTPUT,
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    # ---------------------------------------------------------------
    # Demo 01 — Data Lake (núcleo): raw -> cleaned -> curated
    # ---------------------------------------------------------------
    with Cluster("Demo 01 — Data Lake (S3 + Glue + EventBridge)"):
        raw = S3("raw/")
        cleaned = S3("cleaned/")
        curated = S3("curated/")

        trigger = Lambda("glue-trigger")
        job1 = Glue("raw→cleaned")
        job2 = Glue("cleaned→curated")
        evb = Eventbridge("EventBridge")

        # Gatilho por evento S3 -> EventBridge -> Lambda (laranja)
        raw >> Edge(label="Object Created", **EVENT) >> evb
        cleaned >> Edge(label="Object Created", **EVENT) >> evb
        evb >> Edge(**EVENT) >> trigger

        # Processamento / fluxo de dados (cinza)
        trigger >> Edge(**DATA) >> job1 >> Edge(**DATA) >> cleaned
        trigger >> Edge(**DATA) >> job2 >> Edge(**DATA) >> curated

        with Cluster("Catálogo e consulta"):
            crawlers = GlueCrawlers("Crawlers")
            catalog = GlueDataCatalog("Glue Data Catalog")
            athena = Athena("Athena")
            # Catalogação / metadados (azul pontilhada) + consulta (cinza)
            crawlers >> Edge(**CATALOG) >> catalog
            catalog >> Edge(label="query", **DATA) >> athena

        # Os crawlers descrevem os dados das 3 zonas no catálogo (metadados)
        [raw, cleaned, curated] >> Edge(**CATALOG) >> crawlers

    # ---------------------------------------------------------------
    # Demo 02 — Lake Formation: camada de governança sobre o catálogo
    # ---------------------------------------------------------------
    with Cluster("Demo 02 — Access Control"):
        lf = LakeFormation("Lake Formation")

    lf >> Edge(label="grants coluna/linha", **GOVERN) >> catalog

    # ---------------------------------------------------------------
    # Demo 04 — Data warehouse (modelo estrela no Redshift)
    # ---------------------------------------------------------------
    with Cluster("Demo 04 — Redshift + Step Functions"):
        sfn_dw = StepFunctions("State Machine")
        glue_dim = Glue("curated→estrela")
        redshift = Redshift("Redshift Serverless")
        sfn_dw >> Edge(**DATA) >> glue_dim >> Edge(label="COPY (Data API)", **DATA) >> redshift

    # Demo 05 — Parquet (EMR Serverless) + comparação no Athena
    with Cluster("Demo 05 — EMR + Parquet"):
        sfn_pq = StepFunctions("State Machine")
        emr = EMR("EMR Serverless")
        parquet = S3("analytics/\nparquet/")
        crawler_pq = GlueCrawlers("Crawler Parquet")
        sfn_pq >> Edge(**DATA) >> emr >> Edge(**DATA) >> parquet
        parquet >> Edge(**CATALOG) >> crawler_pq

    # O fim do job cleaned->curated (SUCCEEDED) dispara ambas as State Machines (evento)
    job2 >> Edge(label="Glue Job SUCCEEDED", **EVENT) >> sfn_dw
    job2 >> Edge(label="Glue Job SUCCEEDED", **EVENT) >> sfn_pq

    # A tabela Parquet também é catalogada (metadados)
    crawler_pq >> Edge(**CATALOG) >> catalog

    # ---------------------------------------------------------------
    # Legenda — mostra o código visual das setas (sem ícones, só as linhas).
    # Cada par de nós-ponto conectados por uma seta ilustra um tipo.
    # ---------------------------------------------------------------
    with Cluster("Legenda (código das setas)"):
        dot = {"shape": "point", "width": "0.06", "color": "gray30"}

        a1 = Node("", **dot); a2 = Node("", **dot)
        b1 = Node("", **dot); b2 = Node("", **dot)
        c1 = Node("", **dot); c2 = Node("", **dot)
        d1 = Node("", **dot); d2 = Node("", **dot)

        a1 >> Edge(label="  fluxo de dados / processamento", **DATA) >> a2
        b1 >> Edge(label="  gatilho por evento AWS", **EVENT) >> b2
        c1 >> Edge(label="  catalogação / metadados (schema sobre S3)", **CATALOG) >> c2
        d1 >> Edge(label="  governança / acesso (Lake Formation)", **GOVERN) >> d2

        # Empilha as quatro linhas verticalmente (invisível) para alinhar a legenda.
        a2 >> Edge(style="invis") >> b1
        b2 >> Edge(style="invis") >> c1
        c2 >> Edge(style="invis") >> d1
