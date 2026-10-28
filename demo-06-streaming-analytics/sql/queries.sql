-- =====================================================================
-- Demo 06 - Consultas Athena sobre os eventos que o Firehose entrega ao S3
-- (ramificação de ingestão analítica do streaming).
--
-- O Firehose escreve JSON Lines em:
--   s3://aws-class-streaming-<ACCOUNT_ID>-<REGION>/events/dt=YYYY-MM-DD/
-- =====================================================================

-- 1) Criar uma tabela externa sobre os dados do Firehose (ajuste o bucket).
--    Uma única vez; depois consulte com as queries abaixo.
CREATE EXTERNAL TABLE IF NOT EXISTS default.streaming_events (
    event_id            STRING,
    event_ts            STRING,
    student_id          STRING,
    course              STRING,
    event_type          STRING,
    region              STRING,
    device              STRING,
    video_position_sec  INT,
    score               DOUBLE
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://aws-class-streaming-<ACCOUNT_ID>-us-east-1/events/';

-- 2) Contagem de eventos por tipo (o que chegou até agora)
SELECT event_type, COUNT(*) AS n
FROM default.streaming_events
GROUP BY event_type
ORDER BY n DESC;

-- 3) Eventos por curso
SELECT course, COUNT(*) AS n
FROM default.streaming_events
GROUP BY course
ORDER BY n DESC;

-- 4) Reproduções de vídeo por região
SELECT region, COUNT(*) AS plays
FROM default.streaming_events
WHERE event_type = 'video_play'
GROUP BY region
ORDER BY plays DESC;

-- 5) Média de score nos quizzes (eventos quiz_submitted)
SELECT course, ROUND(AVG(score), 2) AS score_medio, COUNT(*) AS quizzes
FROM default.streaming_events
WHERE event_type = 'quiz_submitted'
GROUP BY course
ORDER BY score_medio DESC;

-- =====================================================================
-- Nota: o Firehose entrega em micro-batches (a cada ~60s). Os eventos recém
-- enviados levam até ~1 min para aparecer no S3 / Athena. O tempo REAL
-- (segundos) se vê no dashboard do CloudWatch; o Athena é para a análise
-- histórica do acumulado.
-- =====================================================================
