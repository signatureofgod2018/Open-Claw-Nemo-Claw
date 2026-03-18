-- Migration 003: Behavioral Canaries
--
-- "Hacks reveal themselves in silly things" — performance degradation,
-- package bloat, dormant dependencies activating, network latency shifts.
--
-- This migration adds tables for capturing the subtle system behaviors
-- that precede or accompany a breach. These are not security events —
-- they are the canaries in the coal mine.
--
-- Reference: The XZ Utils backdoor (CVE-2024-3094) was discovered because
-- SSH logins were 500ms slower than expected. Not a security alert.
-- A performance anomaly.

BEGIN;

-- ============================================================
-- PERFORMANCE BASELINES & DRIFT
-- ============================================================

-- Captures periodic snapshots of system performance metrics
-- Deviations from rolling baseline trigger investigation
CREATE TABLE telemetry.performance_snapshots (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    metric_category VARCHAR(64)     NOT NULL,  -- 'gateway', 'sandbox', 'network', 'system'
    metric_name     VARCHAR(128)    NOT NULL,
    metric_value    DOUBLE PRECISION NOT NULL,
    unit            VARCHAR(32)     NOT NULL,  -- 'ms', 'bytes', 'count', 'percent', 'bytes/sec'
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE telemetry.performance_snapshots_2026_03
    PARTITION OF telemetry.performance_snapshots
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.performance_snapshots_2026_04
    PARTITION OF telemetry.performance_snapshots
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.performance_snapshots_2026_05
    PARTITION OF telemetry.performance_snapshots
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- Rolling baseline computed from performance_snapshots
-- Updated periodically — anomaly = current reading vs. this baseline
CREATE TABLE telemetry.performance_baselines (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    machine         telemetry.machine_id NOT NULL,
    metric_category VARCHAR(64)     NOT NULL,
    metric_name     VARCHAR(128)    NOT NULL,
    baseline_mean   DOUBLE PRECISION NOT NULL,
    baseline_stddev DOUBLE PRECISION NOT NULL,
    sample_count    INTEGER         NOT NULL DEFAULT 0,
    window_hours    INTEGER         NOT NULL DEFAULT 168,  -- 7 days default
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (machine, metric_category, metric_name)
);

-- ============================================================
-- PACKAGE & DEPENDENCY TRACKING
-- ============================================================

-- Tracks installed packages, their sizes, and activation status
-- Flags: size increases, dormant packages that suddenly activate,
-- new transitive dependencies appearing
CREATE TABLE telemetry.package_inventory (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    snapshot_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    package_name    VARCHAR(512)    NOT NULL,
    version         VARCHAR(64)     NOT NULL,
    size_bytes      BIGINT          NOT NULL,
    dependency_count INTEGER        NOT NULL DEFAULT 0,  -- transitive deps
    has_install_scripts BOOLEAN     NOT NULL DEFAULT FALSE,
    maintainer_count INTEGER,
    last_publish    TIMESTAMPTZ,
    source          VARCHAR(64)     NOT NULL DEFAULT 'npm'  -- 'npm', 'system', 'pip'
);

-- Tracks changes between package inventory snapshots
-- "Package got bigger" or "new dependency appeared" shows up here
CREATE TABLE telemetry.package_changes (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    detected_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    package_name    VARCHAR(512)    NOT NULL,
    change_type     VARCHAR(32)     NOT NULL,  -- 'size_increase', 'size_decrease', 'version_change', 'new_dependency', 'removed_dependency', 'new_package', 'removed_package', 'maintainer_change', 'install_script_added'
    old_value       TEXT,
    new_value       TEXT,
    delta_bytes     BIGINT,         -- size change in bytes
    risk_level      telemetry.risk_level NOT NULL DEFAULT 'info',
    investigated    BOOLEAN         NOT NULL DEFAULT FALSE,
    investigation_notes TEXT
);

-- Tracks when packages are actually used (imported, loaded, invoked)
-- A package that is never used... until it suddenly is = red flag
CREATE TABLE telemetry.package_activation (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    package_name    VARCHAR(512)    NOT NULL,
    activation_type VARCHAR(32)     NOT NULL,  -- 'import', 'require', 'exec', 'load'
    invoked_by      VARCHAR(256),   -- which agent or process
    first_seen      BOOLEAN         NOT NULL DEFAULT FALSE  -- TRUE = this package was never used before
);

-- ============================================================
-- NETWORK BEHAVIOR TRACKING
-- ============================================================

-- Tracks network latency and throughput over time
-- "Network is slow" is a security signal
CREATE TABLE telemetry.network_latency (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    target_host     VARCHAR(512)    NOT NULL,
    latency_ms      DOUBLE PRECISION NOT NULL,
    throughput_bps  DOUBLE PRECISION,  -- bytes per second
    packet_loss_pct DOUBLE PRECISION DEFAULT 0,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE telemetry.network_latency_2026_03
    PARTITION OF telemetry.network_latency
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.network_latency_2026_04
    PARTITION OF telemetry.network_latency
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.network_latency_2026_05
    PARTITION OF telemetry.network_latency
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- DNS resolution tracking — new or changed DNS responses
CREATE TABLE telemetry.dns_observations (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    query_name      VARCHAR(512)    NOT NULL,
    resolved_ip     INET            NOT NULL,
    ttl_seconds     INTEGER,
    first_seen      BOOLEAN         NOT NULL DEFAULT FALSE,  -- new resolution = flag
    ip_changed      BOOLEAN         NOT NULL DEFAULT FALSE   -- IP changed from last = flag
);

-- ============================================================
-- RESOURCE UTILIZATION (system-level canaries)
-- ============================================================

-- CPU, memory, disk, file descriptors — sampled periodically
-- Unexplained resource consumption = investigation trigger
CREATE TABLE telemetry.resource_utilization (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    cpu_percent     DOUBLE PRECISION,
    memory_used_mb  DOUBLE PRECISION,
    memory_total_mb DOUBLE PRECISION,
    disk_used_mb    DOUBLE PRECISION,
    disk_total_mb   DOUBLE PRECISION,
    open_file_descriptors INTEGER,
    active_processes INTEGER,
    network_connections_established INTEGER,
    network_connections_listening INTEGER,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE telemetry.resource_utilization_2026_03
    PARTITION OF telemetry.resource_utilization
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE telemetry.resource_utilization_2026_04
    PARTITION OF telemetry.resource_utilization
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE telemetry.resource_utilization_2026_05
    PARTITION OF telemetry.resource_utilization
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- ============================================================
-- PROCESS INVENTORY
-- ============================================================

-- Periodic snapshot of running processes
-- New unexpected process = investigate
CREATE TABLE telemetry.process_inventory (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    snapshot_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    machine         telemetry.machine_id NOT NULL,
    pid             INTEGER         NOT NULL,
    process_name    VARCHAR(256)    NOT NULL,
    command_line    TEXT,
    user_name       VARCHAR(128),
    cpu_percent     DOUBLE PRECISION,
    memory_mb       DOUBLE PRECISION,
    started_at      TIMESTAMPTZ,
    parent_pid      INTEGER,
    first_seen      BOOLEAN         NOT NULL DEFAULT FALSE  -- new process = flag
);

-- ============================================================
-- CANARY VIEWS — Grafana dashboards for behavioral anomalies
-- ============================================================

-- Performance drift: metrics that deviated >2 stddev from baseline
CREATE VIEW telemetry.v_performance_anomalies AS
SELECT
    ps.timestamp,
    ps.machine,
    ps.metric_category,
    ps.metric_name,
    ps.metric_value,
    ps.unit,
    pb.baseline_mean,
    pb.baseline_stddev,
    CASE
        WHEN pb.baseline_stddev > 0 THEN
            ABS(ps.metric_value - pb.baseline_mean) / pb.baseline_stddev
        ELSE 0
    END AS z_score
FROM telemetry.performance_snapshots ps
JOIN telemetry.performance_baselines pb
    ON ps.machine = pb.machine
    AND ps.metric_category = pb.metric_category
    AND ps.metric_name = pb.metric_name
WHERE ps.timestamp > NOW() - INTERVAL '24 hours'
    AND pb.baseline_stddev > 0
    AND ABS(ps.metric_value - pb.baseline_mean) > 2 * pb.baseline_stddev
ORDER BY z_score DESC;

-- Package changes requiring investigation
CREATE VIEW telemetry.v_suspicious_package_changes AS
SELECT *
FROM telemetry.package_changes
WHERE investigated = FALSE
    AND (
        change_type IN ('install_script_added', 'maintainer_change', 'new_package')
        OR (change_type = 'size_increase' AND delta_bytes > 100000)  -- >100KB increase
        OR risk_level IN ('high', 'critical')
    )
ORDER BY detected_at DESC;

-- Dormant packages that just activated (sleeper detection)
CREATE VIEW telemetry.v_dormant_package_activations AS
SELECT
    pa.timestamp,
    pa.machine,
    pa.package_name,
    pa.activation_type,
    pa.invoked_by,
    pi.size_bytes,
    pi.dependency_count,
    pi.has_install_scripts,
    pi.maintainer_count
FROM telemetry.package_activation pa
LEFT JOIN LATERAL (
    SELECT * FROM telemetry.package_inventory pi2
    WHERE pi2.package_name = pa.package_name
        AND pi2.machine = pa.machine
    ORDER BY pi2.snapshot_at DESC
    LIMIT 1
) pi ON TRUE
WHERE pa.first_seen = TRUE
ORDER BY pa.timestamp DESC;

-- Network latency drift (compared to baseline)
CREATE VIEW telemetry.v_network_latency_drift AS
SELECT
    nl.timestamp,
    nl.machine,
    nl.target_host,
    nl.latency_ms,
    pb.baseline_mean AS baseline_latency_ms,
    nl.latency_ms - pb.baseline_mean AS drift_ms,
    CASE
        WHEN pb.baseline_stddev > 0 THEN
            (nl.latency_ms - pb.baseline_mean) / pb.baseline_stddev
        ELSE 0
    END AS z_score,
    nl.packet_loss_pct
FROM telemetry.network_latency nl
JOIN telemetry.performance_baselines pb
    ON nl.machine = pb.machine
    AND pb.metric_category = 'network'
    AND pb.metric_name = 'latency_' || nl.target_host
WHERE nl.timestamp > NOW() - INTERVAL '24 hours'
    AND pb.baseline_stddev > 0
    AND (nl.latency_ms - pb.baseline_mean) > 2 * pb.baseline_stddev
ORDER BY z_score DESC;

-- New DNS resolutions (never-before-seen domains or changed IPs)
CREATE VIEW telemetry.v_new_dns_observations AS
SELECT *
FROM telemetry.dns_observations
WHERE (first_seen = TRUE OR ip_changed = TRUE)
    AND timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Resource utilization spikes (>90% CPU or memory)
CREATE VIEW telemetry.v_resource_spikes AS
SELECT *
FROM telemetry.resource_utilization
WHERE timestamp > NOW() - INTERVAL '24 hours'
    AND (
        cpu_percent > 90
        OR (memory_used_mb / NULLIF(memory_total_mb, 0)) > 0.9
        OR (disk_used_mb / NULLIF(disk_total_mb, 0)) > 0.9
    )
ORDER BY timestamp DESC;

-- New processes (never-before-seen on this machine)
CREATE VIEW telemetry.v_new_processes AS
SELECT *
FROM telemetry.process_inventory
WHERE first_seen = TRUE
    AND snapshot_at > NOW() - INTERVAL '24 hours'
ORDER BY snapshot_at DESC;

-- ============================================================
-- INDEXES for canary tables
-- ============================================================

CREATE INDEX idx_perf_snapshots_timestamp ON telemetry.performance_snapshots (timestamp DESC);
CREATE INDEX idx_perf_snapshots_metric ON telemetry.performance_snapshots (machine, metric_category, metric_name, timestamp DESC);

CREATE INDEX idx_pkg_changes_uninvestigated ON telemetry.package_changes (detected_at DESC)
    WHERE investigated = FALSE;
CREATE INDEX idx_pkg_activation_first ON telemetry.package_activation (timestamp DESC)
    WHERE first_seen = TRUE;

CREATE INDEX idx_net_latency_timestamp ON telemetry.network_latency (timestamp DESC);
CREATE INDEX idx_net_latency_host ON telemetry.network_latency (target_host, timestamp DESC);

CREATE INDEX idx_dns_new ON telemetry.dns_observations (timestamp DESC)
    WHERE first_seen = TRUE OR ip_changed = TRUE;

CREATE INDEX idx_resource_util_timestamp ON telemetry.resource_utilization (timestamp DESC);
CREATE INDEX idx_resource_util_spikes ON telemetry.resource_utilization (timestamp DESC)
    WHERE cpu_percent > 90;

CREATE INDEX idx_process_new ON telemetry.process_inventory (snapshot_at DESC)
    WHERE first_seen = TRUE;

-- ============================================================
-- Update partition creation function to include new tables
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
        'resource_utilization'
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
