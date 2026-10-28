-- =====================================================================
-- Zona CLEANED - dados já normalizados pelo job raw->cleaned
-- =====================================================================
-- Objetivo na demo: mostrar o RESULTADO da primeira limpeza.
-- Ajuste o nome da tabela ao que o crawler registrar
-- (verifique com SHOW TABLES IN aws_class_datalake;).

-- 1) Dados limpos: datas em ISO, cursos e eventos normalizados
SELECT event_id, student_id, course, event_type, event_ts,
       duration_seconds, region, device
FROM aws_class_datalake.cleaned_cleaned
ORDER BY event_ts
LIMIT 20;

-- 2) Não há mais duplicatas nem lixo: contagem por tipo de evento
SELECT event_type, COUNT(*) AS n
FROM aws_class_datalake.cleaned_cleaned
GROUP BY event_type
ORDER BY n DESC;

-- 3) Cursos agora consistentes (Title Case, siglas corretas)
SELECT course, COUNT(*) AS eventos
FROM aws_class_datalake.cleaned_cleaned
GROUP BY course
ORDER BY eventos DESC;

-- 4) Distribuição por region (já normalizada para MAIÚSCULAS)
SELECT region, COUNT(*) AS eventos
FROM aws_class_datalake.cleaned_cleaned
GROUP BY region
ORDER BY eventos DESC;
