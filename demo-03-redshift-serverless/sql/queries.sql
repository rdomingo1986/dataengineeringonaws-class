-- =====================================================================
-- Demo 03 - Consultas de exemplo sobre a tabela enrollments (Redshift)
-- Usar com: scripts\03-query.cmd "<consulta>"  ou no Query Editor v2.
-- =====================================================================

-- 1) Matrículas e receita por curso
SELECT course, COUNT(*) AS matriculas, SUM(price) AS receita
FROM enrollments
GROUP BY course
ORDER BY receita DESC;

-- 2) Matrículas por região
SELECT region, COUNT(*) AS matriculas
FROM enrollments
GROUP BY region
ORDER BY matriculas DESC;

-- 3) Taxa de conclusão por curso (status = completed)
SELECT
    course,
    COUNT(*) AS total,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS concluidas,
    ROUND(100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_conclusao
FROM enrollments
GROUP BY course
ORDER BY pct_conclusao DESC;

-- 4) Receita por mês (aproveita o SORTKEY enrolled_at)
SELECT DATE_TRUNC('month', enrolled_at) AS mes, SUM(price) AS receita
FROM enrollments
WHERE status <> 'cancelled'
GROUP BY mes
ORDER BY mes;

-- 5) Matrículas canceladas (perda potencial)
SELECT course, COUNT(*) AS canceladas, SUM(price) AS receita_perdida
FROM enrollments
WHERE status = 'cancelled'
GROUP BY course
ORDER BY receita_perdida DESC;
