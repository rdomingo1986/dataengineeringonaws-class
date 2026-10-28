"""
EMR Serverless (PySpark) - curated JSON -> Parquet.

Le a zona curada do data lake (Demo 01), que esta em JSON Lines, e a reescreve
em formato PARQUET (colunar, comprimido) em um prefixo de analitica. O objetivo
didatico e comparar depois, no Athena, a velocidade e os bytes varridos
entre a tabela JSON (curated_curated) e a tabela Parquet (curated_parquet).

Argumentos (passados como --arg ao job do EMR Serverless):
  --data_bucket   bucket do data lake
  --input_prefix  prefixo de entrada (curated JSON)
  --output_prefix prefixo de saida (Parquet)

Nao usa bibliotecas do Glue: PySpark puro, portavel para o EMR Serverless.
"""

import argparse

from pyspark.sql import SparkSession


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_bucket", required=True)
    parser.add_argument("--input_prefix", default="curated/student-engagement/")
    parser.add_argument("--output_prefix", default="analytics/student-engagement-parquet/")
    args = parser.parse_args()

    input_path = f"s3://{args.data_bucket}/{args.input_prefix}"
    output_path = f"s3://{args.data_bucket}/{args.output_prefix}"

    spark = (
        SparkSession.builder
        .appName("curated-json-to-parquet")
        .getOrCreate()
    )
    print(f"[json->parquet] lendo JSON de {input_path}")

    # Le JSON Lines e DESCOBRE as particoes do caminho: apontando para a raiz
    # (curated/student-engagement/), o Spark detecta 'event_date' das pastas
    # event_date=.../ e a adiciona como coluna. ATENCAO: NAO usar recursiveFileLookup,
    # porque essa opcao DESATIVA a descoberta de particoes e entao
    # 'event_date' nao aparece no esquema (e o partitionBy da saida falha).
    df = spark.read.json(input_path)

    total = df.count()
    print(f"[json->parquet] registros lidos: {total}")

    # Escrever Parquet particionado por event_date (mesmo criterio da zona
    # curada). Snappy e a compressao padrao do Parquet no Spark.
    (
        df.write
        .mode("overwrite")
        .partitionBy("event_date")
        .parquet(output_path)
    )
    print(f"[json->parquet] Parquet escrito em {output_path}")

    spark.stop()


if __name__ == "__main__":
    main()
