-- =====================================================================
-- Demo 04 - Esquema do modelo estrela no Amazon Redshift
-- Executar no Query Editor v2 (ou a State Machine o executa via Data API).
-- =====================================================================

-- Dimensões pequenas: DISTSTYLE ALL (replicadas em cada nó, joins rápidos).
CREATE TABLE IF NOT EXISTS dim_student (
    student_id    VARCHAR(32)  NOT NULL,
    student_name  VARCHAR(256),
    student_email VARCHAR(256),
    region        VARCHAR(16),
    country       VARCHAR(8),
    PRIMARY KEY (student_id)
)
DISTSTYLE ALL;

CREATE TABLE IF NOT EXISTS dim_course (
    course_id    VARCHAR(128) NOT NULL,
    course_name  VARCHAR(256),
    PRIMARY KEY (course_id)
)
DISTSTYLE ALL;

-- Tabela de fatos: distribuída por student_id (join frequente) e ordenada
-- por event_date (filtros temporais típicos de BI).
CREATE TABLE IF NOT EXISTS fact_engagement (
    event_id         VARCHAR(32)  NOT NULL,
    student_id       VARCHAR(32),
    course_id        VARCHAR(128),
    event_type       VARCHAR(32),
    event_ts         VARCHAR(32),
    event_date       DATE,
    study_minutes    DOUBLE PRECISION,
    score            DOUBLE PRECISION,
    engagement_level VARCHAR(16),
    is_completed     BOOLEAN,
    PRIMARY KEY (event_id)
)
DISTKEY (student_id)
SORTKEY (event_date);

-- Esvaziar antes de recarregar (a demo recarrega o conjunto completo).
TRUNCATE TABLE fact_engagement;
TRUNCATE TABLE dim_student;
TRUNCATE TABLE dim_course;
