-- =====================================================================
-- Zona RAW - dados brutos "sujos" (antes da limpeza)
-- =====================================================================
-- Objetivo na demo: mostrar POR QUE é preciso limpar.
-- Ajuste o nome da tabela ao que o crawler registrar
-- (o crawler a nomeia raw_raw). Verifique com SHOW TABLES.

-- 1) Visão geral dos dados brutos
SELECT *
FROM aws_class_datalake.raw_raw
LIMIT 20;

-- 2) Evidência de sujeira: formatos de data mistos
SELECT DISTINCT event_ts
FROM aws_class_datalake.raw_raw
ORDER BY 1;

-- 3) Evidência de sujeira: nomes de curso inconsistentes
--    (maiúsculas/minúsculas, espaços)
SELECT course, COUNT(*) AS n
FROM aws_class_datalake.raw_raw
GROUP BY course
ORDER BY n DESC;

-- 4) Evidência de sujeira: tipos de evento sem normalizar
SELECT event_type, COUNT(*) AS n
FROM aws_class_datalake.raw_raw
GROUP BY event_type
ORDER BY n DESC;

-- 5) Registros problemáticos (sem student_id ou com duration não numérico)
SELECT event_id, student_id, duration_seconds, event_ts
FROM aws_class_datalake.raw_raw
WHERE student_id IS NULL
   OR NOT regexp_like(CAST(duration_seconds AS varchar), '^[0-9]+$');
