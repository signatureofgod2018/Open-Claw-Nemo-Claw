-- Migration 004: Local Inference Telemetry (Ollama)
--
-- Tracks local model inference performance, token usage, and anomalies.
-- Key canary: inference latency drift = the XZ Utils signal for LLM workloads.
-- If a model suddenly runs slower with no load change, something is wrong.

BEGIN;

-- ============================================================
-- INFERENCE TRACKING
-- ============================================================

-- Every inference request through the Ollama metrics proxy
CREATE TABLE telemetry.inference_requests (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine             telemetry.machine_id NOT NULL,
    model_name          VARCHAR(256)    NOT NULL,
    requesting_agent    VARCHAR(128),
    prompt_tokens       INTEGER         NOT NULL,
    generated_tokens    INTEGER         NOT NULL,
    total_duration_ms   DOUBLE PRECISION NOT NULL,
    load_duration_ms    DOUBLE PRECISION,
    prompt_eval_ms      DOUBLE PRECISION,
    generation_ms       DOUBLE PRECISION,
    time_per_token_ms   DOUBLE PRECISION,
    gpu_offload         BOOLEAN         DEFAULT TRUE,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE telemetry.inference_requests_2026_03
    PARTITION OF telemetry.inference_requests
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.inference_requests_2026_04
    PARTITION OF telemetry.inference_requests
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.inference_requests_2026_05
    PARTITION OF telemetry.inference_requests
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Model load/unload events — tracks what's in GPU memory
CREATE TABLE telemetry.model_lifecycle (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    model_name      VARCHAR(256)    NOT NULL,
    event           VARCHAR(32)     NOT NULL,  -- 'load', 'unload', 'swap'
    ram_mb          DOUBLE PRECISION,
    vram_mb         DOUBLE PRECISION,
    load_duration_ms DOUBLE PRECISION
);

-- Rolling inference baselines per model
CREATE TABLE telemetry.inference_baselines (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    machine         telemetry.machine_id NOT NULL,
    model_name      VARCHAR(256)    NOT NULL,
    metric_name     VARCHAR(128)    NOT NULL,  -- 'time_per_token_ms', 'total_duration_ms', 'prompt_eval_ms'
    baseline_mean   DOUBLE PRECISION NOT NULL,
    baseline_stddev DOUBLE PRECISION NOT NULL,
    sample_count    INTEGER         NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (machine, model_name, metric_name)
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_inference_timestamp ON telemetry.inference_requests (timestamp DESC);
CREATE INDEX idx_inference_model ON telemetry.inference_requests (model_name, timestamp DESC);
CREATE INDEX idx_inference_agent ON telemetry.inference_requests (requesting_agent, timestamp DESC);
CREATE INDEX idx_inference_slow ON telemetry.inference_requests (timestamp DESC)
    WHERE time_per_token_ms > 100;  -- flag slow inference

CREATE INDEX idx_model_lifecycle_timestamp ON telemetry.model_lifecycle (timestamp DESC);
CREATE INDEX idx_model_lifecycle_model ON telemetry.model_lifecycle (model_name, timestamp DESC);

-- ============================================================
-- VIEWS — Grafana dashboards for inference monitoring
-- ============================================================

-- Inference latency trend (hourly) — the core canary
CREATE VIEW telemetry.v_inference_latency_trend AS
SELECT
    DATE_TRUNC('hour', timestamp) AS hour,
    machine,
    model_name,
    COUNT(*) AS request_count,
    AVG(time_per_token_ms) AS avg_time_per_token_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY time_per_token_ms) AS p50_time_per_token_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY time_per_token_ms) AS p95_time_per_token_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY time_per_token_ms) AS p99_time_per_token_ms,
    AVG(total_duration_ms) AS avg_total_ms,
    SUM(prompt_tokens) AS total_prompt_tokens,
    SUM(generated_tokens) AS total_generated_tokens
FROM telemetry.inference_requests
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', timestamp), machine, model_name
ORDER BY hour DESC;

-- Inference anomalies (>2σ from baseline)
CREATE VIEW telemetry.v_inference_anomalies AS
SELECT
    ir.timestamp,
    ir.machine,
    ir.model_name,
    ir.requesting_agent,
    ir.time_per_token_ms,
    ib.baseline_mean,
    ib.baseline_stddev,
    CASE
        WHEN ib.baseline_stddev > 0 THEN
            (ir.time_per_token_ms - ib.baseline_mean) / ib.baseline_stddev
        ELSE 0
    END AS z_score,
    ir.prompt_tokens,
    ir.generated_tokens,
    ir.total_duration_ms
FROM telemetry.inference_requests ir
JOIN telemetry.inference_baselines ib
    ON ir.machine = ib.machine
    AND ir.model_name = ib.model_name
    AND ib.metric_name = 'time_per_token_ms'
WHERE ir.timestamp > NOW() - INTERVAL '24 hours'
    AND ib.baseline_stddev > 0
    AND (ir.time_per_token_ms - ib.baseline_mean) > 2 * ib.baseline_stddev
ORDER BY z_score DESC;

-- Token usage by agent (cost tracking and abuse detection)
CREATE VIEW telemetry.v_token_usage_by_agent AS
SELECT
    requesting_agent,
    model_name,
    machine,
    DATE_TRUNC('day', timestamp) AS day,
    COUNT(*) AS request_count,
    SUM(prompt_tokens) AS total_prompt_tokens,
    SUM(generated_tokens) AS total_generated_tokens,
    SUM(prompt_tokens + generated_tokens) AS total_tokens,
    AVG(time_per_token_ms) AS avg_time_per_token_ms
FROM telemetry.inference_requests
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY requesting_agent, model_name, machine, DATE_TRUNC('day', timestamp)
ORDER BY day DESC, total_tokens DESC;

-- Model load frequency (frequent reloads = memory pressure)
CREATE VIEW telemetry.v_model_load_frequency AS
SELECT
    model_name,
    machine,
    DATE_TRUNC('hour', timestamp) AS hour,
    COUNT(*) FILTER (WHERE event = 'load') AS loads,
    COUNT(*) FILTER (WHERE event = 'unload') AS unloads,
    COUNT(*) FILTER (WHERE event = 'swap') AS swaps,
    AVG(load_duration_ms) AS avg_load_ms
FROM telemetry.model_lifecycle
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY model_name, machine, DATE_TRUNC('hour', timestamp)
ORDER BY hour DESC;

-- ============================================================
-- Update partition function to include inference_requests
-- ============================================================

CREATE OR REPLACE FUNCTION telemetry.create_monthly_partitions(months_ahead INTEGER DEFAULT 3)
RETURNS void AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
    i INTEGER;
    tables_to_partition TEXT[] := ARRAY[
        'security_events',
        'network_requests',
        'performance_snapshots',
        'network_latency',
        'resource_utilization',
        'inference_requests'
    ];
    tbl TEXT;
BEGIN
    FOR i IN 0..months_ahead LOOP
        start_date := DATE_TRUNC('month', CURRENT_DATE + (i || ' months')::interval);
        end_date := start_date + INTERVAL '1 month';

        FOREACH tbl IN ARRAY tables_to_partition LOOP
            partition_name := 'telemetry.' || tbl || '_' || TO_CHAR(start_date, 'YYYY_MM');
            IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = tbl || '_' || TO_CHAR(start_date, 'YYYY_MM')) THEN
                EXECUTE format(
                    'CREATE TABLE %s PARTITION OF telemetry.%I FOR VALUES FROM (%L) TO (%L)',
                    partition_name, tbl, start_date, end_date
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;
