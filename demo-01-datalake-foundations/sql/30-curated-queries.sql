-- =====================================================================
-- Zona CURATED - dados enriquecidos, prontos para analítica de negócio
-- =====================================================================
-- Objetivo na demo: responder perguntas de negócio da plataforma de cursos online.
-- Tabela particionada por event_date. Ajuste o nome conforme o crawler
-- (verifique com SHOW TABLES IN aws_class_datalake;).
--
-- Colunas sensíveis presentes para a Demo 02 (Lake Formation):
--   student_email, cpf_hash, region

-- 1) Engagement por curso: minutos de estudo e conclusões
SELECT
    course,
    COUNT(*)                                AS total_eventos,
    COUNT(DISTINCT student_id)              AS estudantes_unicos,
    ROUND(SUM(study_minutes), 1)            AS minutos_estudo_total,
    SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) AS licoes_concluidas
FROM aws_class_datalake.curated_curated
GROUP BY course
ORDER BY minutos_estudo_total DESC;

-- 2) Horas de estudo por estudante (top 10)
SELECT
    student_id,
    student_name,
    ROUND(SUM(study_minutes) / 60.0, 2) AS horas_estudo
FROM aws_class_datalake.curated_curated
WHERE is_learning_event
GROUP BY student_id, student_name
ORDER BY horas_estudo DESC
LIMIT 10;

-- 3) Distribuição de níveis de engagement
SELECT engagement_level, COUNT(*) AS n
FROM aws_class_datalake.curated_curated
GROUP BY engagement_level
ORDER BY n DESC;

-- 4) Desempenho nos quizzes por curso (média de score)
SELECT
    course,
    ROUND(AVG(score), 2) AS score_medio,
    COUNT(*)             AS quizzes
FROM aws_class_datalake.curated_curated
WHERE event_type = 'quiz_submitted' AND score IS NOT NULL
GROUP BY course
ORDER BY score_medio DESC;

-- 5) Atividade por data (aproveita a partição event_date)
SELECT event_date, COUNT(*) AS eventos
FROM aws_class_datalake.curated_curated
GROUP BY event_date
ORDER BY event_date;

-- 6) Prévia para o Lake Formation (Demo 02):
--    as mesmas linhas, mas expondo colunas sensíveis.
--    Na Demo 02 vamos restringir student_email / cpf_hash (column-level)
--    e filtrar por region (row-level / LF-Tags).
SELECT student_id, student_email, cpf_hash, region, course, engagement_level
FROM aws_class_datalake.curated_curated
ORDER BY region, student_id
LIMIT 20;
