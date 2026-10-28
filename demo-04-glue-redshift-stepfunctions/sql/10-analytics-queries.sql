-- =====================================================================
-- Demo 04 - Consultas de negócio sobre o modelo estrela (Redshift)
-- Executar no Query Editor v2 após carregar as tabelas.
-- Demonstram joins fato-dimensão, que é o padrão de um data warehouse.
-- =====================================================================

-- 1) Engagement por curso (join fact + dim_course)
SELECT
    c.course_name,
    COUNT(*)                         AS eventos,
    COUNT(DISTINCT f.student_id)     AS estudantes,
    ROUND(SUM(f.study_minutes), 1)   AS minutos_estudo,
    SUM(CASE WHEN f.is_completed THEN 1 ELSE 0 END) AS licoes_concluidas
FROM fact_engagement f
JOIN dim_course c ON f.course_id = c.course_id
GROUP BY c.course_name
ORDER BY minutos_estudo DESC;

-- 2) Engagement por região (join fact + dim_student)
SELECT
    s.region,
    COUNT(*)                       AS eventos,
    ROUND(AVG(f.study_minutes), 2) AS media_minutos
FROM fact_engagement f
JOIN dim_student s ON f.student_id = s.student_id
GROUP BY s.region
ORDER BY eventos DESC;

-- 3) Top estudantes por horas de estudo
SELECT
    s.student_name,
    s.region,
    ROUND(SUM(f.study_minutes) / 60.0, 2) AS horas_estudo
FROM fact_engagement f
JOIN dim_student s ON f.student_id = s.student_id
GROUP BY s.student_name, s.region
ORDER BY horas_estudo DESC
LIMIT 10;

-- 4) Desempenho nos quizzes por curso
SELECT
    c.course_name,
    ROUND(AVG(f.score), 2) AS score_medio,
    COUNT(*)               AS quizzes
FROM fact_engagement f
JOIN dim_course c ON f.course_id = c.course_id
WHERE f.event_type = 'quiz_submitted' AND f.score IS NOT NULL
GROUP BY c.course_name
ORDER BY score_medio DESC;

-- 5) Atividade por data (aproveita o SORTKEY event_date)
SELECT event_date, COUNT(*) AS eventos
FROM fact_engagement
GROUP BY event_date
ORDER BY event_date;
