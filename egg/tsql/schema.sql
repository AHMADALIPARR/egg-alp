-- EGG-001 T-SQL schema.  STATUS: SYNTAX-ONLY check (python sqlglot, dialect tsql). NOT run on SQL Server (none installed).
-- Rules encoded: valid count is 0..200 or NULL; NULL means "not recorded" and is never stored as 0;
-- timestamps are UTC; source metadata is immutable (no UPDATE/DELETE allowed by the trigger).
CREATE TABLE dbo.source_file (
    source_file_id INT IDENTITY(1,1) PRIMARY KEY,
    file_name      NVARCHAR(260) NOT NULL,
    sha256         CHAR(64)      NOT NULL UNIQUE,
    byte_count     BIGINT        NOT NULL,
    loaded_utc     DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
CREATE TABLE dbo.source_metadata (
    source_file_id INT           NOT NULL REFERENCES dbo.source_file(source_file_id),
    line_no        INT           NOT NULL,
    meta_key       NVARCHAR(100) NOT NULL,
    meta_value     NVARCHAR(400) NULL,
    PRIMARY KEY (source_file_id, line_no)
);
GO
CREATE TRIGGER dbo.trg_source_metadata_immutable ON dbo.source_metadata
INSTEAD OF UPDATE, DELETE AS
BEGIN
    RAISERROR('source_metadata is immutable', 16, 1);
END;
GO
CREATE TABLE dbo.device (
    device_id      INT           NOT NULL PRIMARY KEY,
    first_seen_utc DATETIME2(0)  NULL,
    note           NVARCHAR(200) NULL
);
GO
CREATE TABLE dbo.measurement (
    source_file_id INT           NOT NULL REFERENCES dbo.source_file(source_file_id),
    device_id      INT           NOT NULL REFERENCES dbo.device(device_id),
    t_utc          DATETIME2(0)  NOT NULL,
    valid_count    TINYINT       NULL,
    CONSTRAINT pk_measurement PRIMARY KEY (source_file_id, device_id, t_utc),
    CONSTRAINT ck_valid_count_range CHECK (valid_count IS NULL OR valid_count BETWEEN 0 AND 200)
);
GO
CREATE INDEX ix_measurement_time ON dbo.measurement (t_utc, device_id) INCLUDE (valid_count);
GO
CREATE TABLE dbo.experiment (
    experiment_id  INT IDENTITY(1,1) PRIMARY KEY,
    code           NVARCHAR(40)  NOT NULL UNIQUE,
    seed_base      INT           NOT NULL,
    has_holdout    BIT           NOT NULL DEFAULT 0,
    description    NVARCHAR(400) NULL
);
GO
CREATE TABLE dbo.metric (
    metric_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    experiment_id  INT           NOT NULL REFERENCES dbo.experiment(experiment_id),
    metric_name    NVARCHAR(100) NOT NULL,
    device_id      INT           NULL REFERENCES dbo.device(device_id),
    window_s       INT           NULL,
    t_start_utc    DATETIME2(0)  NULL,
    n_observed     INT           NULL,
    value          FLOAT         NULL,
    p_raw          FLOAT         NULL,
    p_adjusted     FLOAT         NULL,
    adjustment     NVARCHAR(20)  NULL,
    status         NVARCHAR(30)  NOT NULL DEFAULT N'EXPLORATORY'
);
GO
CREATE TABLE dbo.provenance (
    provenance_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
    experiment_id  INT           NOT NULL REFERENCES dbo.experiment(experiment_id),
    artifact_path  NVARCHAR(260) NOT NULL,
    sha256         CHAR(64)      NOT NULL,
    produced_by    NVARCHAR(100) NOT NULL,
    produced_utc   DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
-- Indexed time-window query: observed count, mean and variance per device in a window. Missing rows are excluded, not zero-filled.
-- SELECT device_id, COUNT(valid_count) AS n_obs, AVG(CAST(valid_count AS FLOAT)) AS mean_x, VAR(CAST(valid_count AS FLOAT)) AS var_x
-- FROM dbo.measurement WHERE t_utc >= @t0 AND t_utc < @t1 GROUP BY device_id;
