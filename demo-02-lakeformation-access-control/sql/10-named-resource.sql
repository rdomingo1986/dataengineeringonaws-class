-- =====================================================================
-- Demo 02 - Modelo NAMED RESOURCE
-- Executar DEPOIS de fazer switch para o papel: aws-class-lf-named-resource
-- =====================================================================
-- Banco de dados: aws_class_datalake
-- Workgroup Athena: aws-class-datalake-wg
-- Tabela governada: curated_curated
--
-- Este papel recebeu SELECT sobre a tabela por RECURSO (named), excluindo
-- as colunas PII (student_email, cpf_hash) com column-level security.
-- =====================================================================

-- 1) SELECT * : funciona, mas as colunas PII NÃO aparecem no resultado.
--    (O Lake Formation as filtra porque não foram concedidas a este papel.)
SELECT *
FROM aws_class_datalake.curated_curated
LIMIT 20;

-- 2) Tentativa explícita de ler uma coluna PII -> deve FALHAR / não ser permitido.
--    Descomente para demonstrar o bloqueio:
-- SELECT student_id, student_email, cpf_hash
-- FROM aws_class_datalake.curated_curated
-- LIMIT 10;

-- 3) Consulta de negócio que o modelo PERMITE (sem PII):
--    engagement por curso.
SELECT
    course,
    COUNT(*)                         AS eventos,
    COUNT(DISTINCT student_id)       AS estudantes,
    ROUND(SUM(study_minutes), 1)     AS minutos_estudo
FROM aws_class_datalake.curated_curated
GROUP BY course
ORDER BY minutos_estudo DESC;

-- 4) Verifique que você vê region (não é PII neste modelo) e os níveis de engagement.
SELECT region, engagement_level, COUNT(*) AS n
FROM aws_class_datalake.curated_curated
GROUP BY region, engagement_level
ORDER BY region, n DESC;
