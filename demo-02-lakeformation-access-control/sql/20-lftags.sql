-- =====================================================================
-- Demo 02 - Modelo LF-TAGS (Tag-Based Access Control)
-- Executar DEPOIS de fazer switch para o papel: aws-class-lf-lftags
-- =====================================================================
-- Banco de dados: aws_class_datalake
-- Workgroup Athena: aws-class-datalake-wg
-- Tabela governada: curated_curated
--
-- Este papel NÃO recebeu a tabela por recurso. Recebeu SELECT sobre uma
-- EXPRESSÃO DE LF-TAGS:  zone = curated  AND  sensitivity = non_pii.
-- As colunas PII estão etiquetadas sensitivity=pii, por isso ficam
-- fora do alcance deste papel -> ele não as vê.
-- =====================================================================

-- 1) SELECT * : o papel vê a tabela (pela tag zone=curated) mas SEM as
--    colunas PII (porque só tem acesso a sensitivity=non_pii).
SELECT *
FROM aws_class_datalake.curated_curated
LIMIT 20;

-- 2) Tentativa de ler colunas PII -> não permitido pela política de tags.
--    Descomente para demonstrar:
-- SELECT student_id, student_email, cpf_hash
-- FROM aws_class_datalake.curated_curated
-- LIMIT 10;

-- 3) Consulta de negócio permitida (sem PII): desempenho nos quizzes por curso.
SELECT
    course,
    ROUND(AVG(score), 2) AS score_medio,
    COUNT(*)             AS quizzes
FROM aws_class_datalake.curated_curated
WHERE event_type = 'quiz_submitted' AND score IS NOT NULL
GROUP BY course
ORDER BY score_medio DESC;

-- 4) Demonstração opcional de ROW-LEVEL com LF-Tags / data cell filter:
--    Se você também aplicar um filtro de linha por region (ex.: BR-SP) sobre o
--    grant de tags, este papel só veria linhas dessa região. Execute esta
--    consulta antes e depois de aplicar o filtro para mostrar o efeito:
SELECT region, COUNT(*) AS linhas_visiveis
FROM aws_class_datalake.curated_curated
GROUP BY region
ORDER BY region;
