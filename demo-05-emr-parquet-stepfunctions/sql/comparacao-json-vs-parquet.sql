-- =====================================================================
-- Demo 05 - Comparação de desempenho: JSON vs Parquet no Athena
-- Banco de dados: aws_class_datalake
--   tabela JSON    = curated_curated            (zona curated, JSON Lines)
--   tabela Parquet = parquet_student_engagement_parquet  (ver SHOW TABLES)
--
-- Nota: o nome real da tabela Parquet é atribuído pelo crawler (TablePrefix
-- 'parquet_' + pasta). Verifique com:  SHOW TABLES IN aws_class_datalake;
-- e ajuste o nome nas consultas abaixo se for diferente.
--
-- O QUE OLHAR NO CONSOLE DO ATHENA, para cada consulta:
--   * "Run time"      (tempo de execução)
--   * "Data scanned"  (bytes varridos)  <-- a métrica mais contundente:
--     o Parquet varre MUITO menos que o JSON para a mesma consulta, porque é
--     colunar (só lê as colunas usadas) e está comprimido.
-- =====================================================================

-- ---------- 1) Agregação por curso ----------
-- Sobre JSON:
SELECT course, COUNT(*) AS eventos, ROUND(SUM(study_minutes),1) AS minutos
FROM aws_class_datalake.curated_curated
GROUP BY course
ORDER BY minutos DESC;

-- Sobre PARQUET (mesma consulta; compare Run time e Data scanned):
SELECT course, COUNT(*) AS eventos, ROUND(SUM(study_minutes),1) AS minutos
FROM aws_class_datalake.parquet_student_engagement_parquet
GROUP BY course
ORDER BY minutos DESC;


-- ---------- 2) Seleção de poucas colunas (onde o Parquet mais brilha) ----------
-- O Parquet só lê as colunas pedidas; o JSON lê o objeto inteiro.
-- Sobre JSON:
SELECT region, AVG(study_minutes) AS media_minutos
FROM aws_class_datalake.curated_curated
GROUP BY region;

-- Sobre PARQUET:
SELECT region, AVG(study_minutes) AS media_minutos
FROM aws_class_datalake.parquet_student_engagement_parquet
GROUP BY region;


-- ---------- 3) Filtro + agregação ----------
-- Sobre JSON:
SELECT event_type, COUNT(*) AS n
FROM aws_class_datalake.curated_curated
WHERE engagement_level = 'high'
GROUP BY event_type;

-- Sobre PARQUET:
SELECT event_type, COUNT(*) AS n
FROM aws_class_datalake.parquet_student_engagement_parquet
WHERE engagement_level = 'high'
GROUP BY event_type;

-- =====================================================================
-- Mensagem da demo:
--   Mesma consulta, mesmos dados, dois formatos. O Parquet (colunar,
--   comprimido) varre uma fração dos bytes e responde mais rápido.
--   Com volume (centenas de milhares de linhas) a diferença é notória tanto
--   no tempo como, sobretudo, no "Data scanned" (= menor custo no Athena,
--   que cobra por bytes varridos).
-- =====================================================================
