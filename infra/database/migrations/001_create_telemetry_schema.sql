-- Migration 001: Create telemetry schema and core tables
-- Open-Claw-Nemo-Claw Critical Telemetry Persistence Layer
--
-- Purpose: Persist critical security telemetry for long-term trend analysis,
-- compliance auditing, and anomaly detection. Grafana + Prometheus connect
-- here for dashboarding and alerting on historical data.

BEGIN;

-- Dedicated schema to isolate telemetry from other future schemas
CREATE SCHEMA IF NOT EXISTS telemetry;

-- ============================================================
-- ENUM TYPES
-- ============================================================

CREATE TYPE telemetry.machine_id AS ENUM ('st-gabriel', 'maria');

CREATE TYPE telemetry.risk_level AS ENUM ('info', 'low', 'medium', 'high', 'critical');

CREATE TYPE telemetry.event_type AS ENUM (
    'tool_invocation',
    'memory_write',
    'memory_read',
    'network_request',
    'policy_violation',
    'auth_event',
    'transport_message',
    'skill_invocation',
    'sandbox_event',
    'gateway_health'
);

CREATE TYPE telemetry.owasp_asi AS ENUM (
    'ASI01',  -- Agent Goal Hijacking
    'ASI02',  -- Tool Misuse / Confused Deputy
    'ASI03',  -- Identity & Privilege Abuse
    'ASI04',  -- Supply Chain
    'ASI05',  -- Code Execution
    'ASI06',  -- Memory & Context Poisoning
    'ASI07',  -- Insecure Inter-Agent Communication
    'ASI08',  -- Cascading Failures
    'ASI09',  -- Human-Agent Trust Exploitation
    'ASI10'   -- Rogue Agents
);

-- ============================================================
-- CORE TABLES
-- ============================================================

-- Critical security events — the primary telemetry store
-- Partitioned by month for efficient time-range queries and retention
CREATE TABLE telemetry.security_events (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    agent_id        VARCHAR(128),
    event_type      telemetry.event_type NOT NULL,
    risk_level      telemetry.risk_level NOT NULL,
    owasp_asi       telemetry.owasp_asi,
    correlation_id  UUID,
    summary         TEXT            NOT NULL,
    details         JSONB           NOT NULL DEFAULT '{}',
    source_ip       INET,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Create initial partitions (3 months ahead)
CREATE TABLE telemetry.security_events_2026_03
    PARTITION OF telemetry.security_events
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.security_events_2026_04
    PARTITION OF telemetry.security_events
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.security_events_2026_05
    PARTITION OF telemetry.security_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Integrity-chained audit log for compliance
-- Every entry includes a hash of the previous entry — tamper detection
CREATE TABLE telemetry.audit_log (
    sequence_number BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    agent_id        VARCHAR(128),
    event_type      telemetry.event_type NOT NULL,
    risk_level      telemetry.risk_level NOT NULL DEFAULT 'info',
    correlation_id  UUID,
    details         JSONB           NOT NULL DEFAULT '{}',
    integrity_hash  VARCHAR(71)     NOT NULL  -- 'sha256:' + 64 hex chars
);

-- Agent activity baseline — used for anomaly detection
-- Stores rolling averages per agent for tool invocation rates, memory writes, etc.
CREATE TABLE telemetry.agent_baselines (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_id        VARCHAR(128)    NOT NULL,
    machine         telemetry.machine_id NOT NULL,
    metric_name     VARCHAR(128)    NOT NULL,
    baseline_value  DOUBLE PRECISION NOT NULL,
    sample_count    INTEGER         NOT NULL DEFAULT 0,
    window_start    TIMESTAMPTZ     NOT NULL,
    window_end      TIMESTAMPTZ     NOT NULL,
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (agent_id, machine, metric_name)
);

-- Skill allowlist — only skills in this table are approved for execution
CREATE TABLE telemetry.skill_allowlist (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    skill_name      VARCHAR(256)    NOT NULL UNIQUE,
    source          VARCHAR(256)    NOT NULL,  -- 'local', 'clawhub', 'custom'
    version         VARCHAR(32),
    audited_by      VARCHAR(256)    NOT NULL,
    audited_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    audit_notes     TEXT,
    risk_assessment telemetry.risk_level NOT NULL DEFAULT 'low',
    approved        BOOLEAN         NOT NULL DEFAULT FALSE
);

-- Alert history — tracks all fired alerts and their resolution
CREATE TABLE telemetry.alert_history (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    alert_name      VARCHAR(256)    NOT NULL,
    severity        telemetry.risk_level NOT NULL,
    machine         telemetry.machine_id NOT NULL,
    agent_id        VARCHAR(128),
    owasp_asi       telemetry.owasp_asi,
    description     TEXT            NOT NULL,
    triggered_rule  VARCHAR(128),   -- references anomaly-rules.yml rule ID
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(256),
    resolution_notes TEXT
);

-- Network request log — tracks all outbound requests for exfiltration detection
CREATE TABLE telemetry.network_requests (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    agent_id        VARCHAR(128),
    method          VARCHAR(10),
    host            VARCHAR(512)    NOT NULL,
    port            INTEGER,
    path            TEXT,
    response_code   INTEGER,
    blocked         BOOLEAN         NOT NULL DEFAULT FALSE,
    block_reason    TEXT,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE telemetry.network_requests_2026_03
    PARTITION OF telemetry.network_requests
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.network_requests_2026_04
    PARTITION OF telemetry.network_requests
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.network_requests_2026_05
    PARTITION OF telemetry.network_requests
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- ============================================================
-- INDEXES — optimized for Grafana time-series queries
-- ============================================================

CREATE INDEX idx_security_events_timestamp ON telemetry.security_events (timestamp DESC);
CREATE INDEX idx_security_events_risk ON telemetry.security_events (risk_level, timestamp DESC);
CREATE INDEX idx_security_events_agent ON telemetry.security_events (agent_id, timestamp DESC);
CREATE INDEX idx_security_events_type ON telemetry.security_events (event_type, timestamp DESC);
CREATE INDEX idx_security_events_owasp ON telemetry.security_events (owasp_asi, timestamp DESC)
    WHERE owasp_asi IS NOT NULL;
CREATE INDEX idx_security_events_correlation ON telemetry.security_events (correlation_id)
    WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_security_events_critical ON telemetry.security_events (timestamp DESC)
    WHERE risk_level IN ('high', 'critical');

CREATE INDEX idx_audit_log_timestamp ON telemetry.audit_log (timestamp DESC);
CREATE INDEX idx_audit_log_agent ON telemetry.audit_log (agent_id, timestamp DESC);

CREATE INDEX idx_alert_history_timestamp ON telemetry.alert_history (timestamp DESC);
CREATE INDEX idx_alert_history_unresolved ON telemetry.alert_history (timestamp DESC)
    WHERE resolved_at IS NULL;
CREATE INDEX idx_alert_history_owasp ON telemetry.alert_history (owasp_asi, timestamp DESC)
    WHERE owasp_asi IS NOT NULL;

CREATE INDEX idx_network_requests_timestamp ON telemetry.network_requests (timestamp DESC);
CREATE INDEX idx_network_requests_host ON telemetry.network_requests (host, timestamp DESC);
CREATE INDEX idx_network_requests_blocked ON telemetry.network_requests (timestamp DESC)
    WHERE blocked = TRUE;

-- ============================================================
-- VIEWS — pre-built queries for Grafana dashboards
-- ============================================================

-- Critical events in the last 24 hours
CREATE VIEW telemetry.v_critical_events_24h AS
SELECT *
FROM telemetry.security_events
WHERE risk_level IN ('high', 'critical')
  AND timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Event counts by type and risk level (last 24h) — for Grafana pie/bar charts
CREATE VIEW telemetry.v_event_summary_24h AS
SELECT
    event_type,
    risk_level,
    COUNT(*) as event_count,
    COUNT(DISTINCT agent_id) as affected_agents
FROM telemetry.security_events
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY event_type, risk_level
ORDER BY event_count DESC;

-- OWASP ASI breakdown — trend which threats are most active
CREATE VIEW telemetry.v_owasp_trend AS
SELECT
    owasp_asi,
    DATE_TRUNC('hour', timestamp) as hour,
    COUNT(*) as event_count,
    COUNT(DISTINCT agent_id) as affected_agents
FROM telemetry.security_events
WHERE owasp_asi IS NOT NULL
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY owasp_asi, DATE_TRUNC('hour', timestamp)
ORDER BY hour DESC, event_count DESC;

-- Agent risk score — weighted sum of recent events per agent
CREATE VIEW telemetry.v_agent_risk_scores AS
SELECT
    agent_id,
    machine,
    COUNT(*) FILTER (WHERE risk_level = 'critical') * 10 +
    COUNT(*) FILTER (WHERE risk_level = 'high') * 5 +
    COUNT(*) FILTER (WHERE risk_level = 'medium') * 2 +
    COUNT(*) FILTER (WHERE risk_level = 'low') * 1 AS risk_score,
    COUNT(*) as total_events,
    MAX(timestamp) as last_event
FROM telemetry.security_events
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY agent_id, machine
ORDER BY risk_score DESC;

-- Unresolved alerts
CREATE VIEW telemetry.v_open_alerts AS
SELECT *
FROM telemetry.alert_history
WHERE resolved_at IS NULL
ORDER BY
    CASE severity
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 3
        ELSE 4
    END,
    timestamp DESC;

-- Top contacted hosts (exfiltration trend detection)
CREATE VIEW telemetry.v_top_hosts_24h AS
SELECT
    host,
    COUNT(*) as request_count,
    COUNT(DISTINCT agent_id) as requesting_agents,
    COUNT(*) FILTER (WHERE blocked = TRUE) as blocked_count
FROM telemetry.network_requests
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY host
ORDER BY request_count DESC
LIMIT 50;

-- Hourly event rate — for Grafana time-series panels
CREATE VIEW telemetry.v_hourly_event_rate AS
SELECT
    DATE_TRUNC('hour', timestamp) as hour,
    event_type,
    machine,
    COUNT(*) as event_count
FROM telemetry.security_events
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', timestamp), event_type, machine
ORDER BY hour DESC;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Compute integrity hash for audit log entries
CREATE OR REPLACE FUNCTION telemetry.compute_audit_hash()
RETURNS TRIGGER AS $$
DECLARE
    prev_hash VARCHAR(71);
    hash_input TEXT;
BEGIN
    -- Get the previous entry's hash (or genesis hash for first entry)
    SELECT integrity_hash INTO prev_hash
    FROM telemetry.audit_log
    ORDER BY sequence_number DESC
    LIMIT 1;

    IF prev_hash IS NULL THEN
        prev_hash := 'sha256:0000000000000000000000000000000000000000000000000000000000000000';
    END IF;

    -- Hash = SHA-256(previous_hash + current_entry_json)
    hash_input := prev_hash || row_to_json(NEW)::text;
    NEW.integrity_hash := 'sha256:' || encode(digest(hash_input, 'sha256'), 'hex');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_integrity_hash
    BEFORE INSERT ON telemetry.audit_log
    FOR EACH ROW
    EXECUTE FUNCTION telemetry.compute_audit_hash();

-- Auto-create monthly partitions for security_events and network_requests
CREATE OR REPLACE FUNCTION telemetry.create_monthly_partitions(months_ahead INTEGER DEFAULT 3)
RETURNS void AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
    i INTEGER;
BEGIN
    FOR i IN 0..months_ahead LOOP
        start_date := DATE_TRUNC('month', CURRENT_DATE + (i || ' months')::interval);
        end_date := start_date + INTERVAL '1 month';

        -- security_events partition
        partition_name := 'telemetry.security_events_' || TO_CHAR(start_date, 'YYYY_MM');
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'security_events_' || TO_CHAR(start_date, 'YYYY_MM')) THEN
            EXECUTE format(
                'CREATE TABLE %s PARTITION OF telemetry.security_events FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );
        END IF;

        -- network_requests partition
        partition_name := 'telemetry.network_requests_' || TO_CHAR(start_date, 'YYYY_MM');
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'network_requests_' || TO_CHAR(start_date, 'YYYY_MM')) THEN
            EXECUTE format(
                'CREATE TABLE %s PARTITION OF telemetry.network_requests FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- RETENTION POLICY (call periodically via cron or pg_cron)
-- ============================================================

-- Drop partitions older than retention period
CREATE OR REPLACE FUNCTION telemetry.enforce_retention(retention_months INTEGER DEFAULT 12)
RETURNS void AS $$
DECLARE
    cutoff_date DATE;
    partition_record RECORD;
BEGIN
    cutoff_date := DATE_TRUNC('month', CURRENT_DATE - (retention_months || ' months')::interval);

    FOR partition_record IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'telemetry'
          AND (tablename LIKE 'security_events_%' OR tablename LIKE 'network_requests_%')
    LOOP
        -- Extract date from partition name and drop if older than cutoff
        -- This is a safety check — only drops partitions, never the parent table
        IF partition_record.tablename ~ '_\d{4}_\d{2}$' THEN
            DECLARE
                partition_date DATE;
            BEGIN
                partition_date := TO_DATE(
                    RIGHT(partition_record.tablename, 7), 'YYYY_MM'
                );
                IF partition_date < cutoff_date THEN
                    EXECUTE format('DROP TABLE telemetry.%I', partition_record.tablename);
                    RAISE NOTICE 'Dropped old partition: %', partition_record.tablename;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                NULL; -- Skip partitions with unexpected name formats
            END;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;
