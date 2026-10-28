-- =====================================================================
-- Demo 01 - Setup / referência do Athena  (plataforma de cursos online)
-- =====================================================================
-- O banco de dados e as tabelas são criados pelos CRAWLERS do Glue
-- (scripts/run-crawlers.sh). Este arquivo é apenas de referência.
--
-- Workgroup sugerido:  aws-class-datalake-wg
-- Banco de dados:      aws_class_datalake
--
-- Tabelas geradas pelos crawlers (TablePrefix por zona):
--   raw_raw             -> zona raw/      (dados brutos sem limpar)
--   cleaned_cleaned     -> zona cleaned/  (dados limpos)
--   curated_curated     -> zona curated/  (particionada por event_date)
--
-- Nota: o nome exato da tabela depende do nome da pasta que o crawler
-- detecta. Verifique os nomes reais com:
--   SHOW TABLES IN aws_class_datalake;
-- =====================================================================

SHOW TABLES IN aws_class_datalake;

-- Se o crawler de curated não registrou as partições automaticamente,
-- force a descoberta de partições (ajuste o nome da tabela):
-- MSCK REPAIR TABLE aws_class_datalake.curated_curated;
