-- Migration 002: Database roles and permissions
-- Principle of least privilege — each component gets only the access it needs

BEGIN;

-- Enable pgcrypto for SHA-256 hashing in audit log trigger
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- ROLES
-- ============================================================

-- Telemetry writer — used by OTel Collector and exporters
-- Can INSERT into telemetry tables, cannot UPDATE or DELETE
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'telemetry_writer') THEN
        CREATE ROLE telemetry_writer LOGIN PASSWORD NULL;  -- password set at deploy time
    END IF;
END $$;

GRANT USAGE ON SCHEMA telemetry TO telemetry_writer;
GRANT INSERT ON ALL TABLES IN SCHEMA telemetry TO telemetry_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA telemetry TO telemetry_writer;
-- Explicitly deny UPDATE and DELETE on audit_log (append-only)
REVOKE UPDATE, DELETE ON telemetry.audit_log FROM telemetry_writer;

-- Telemetry reader — used by Grafana for dashboards
-- Can SELECT only, no writes
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'telemetry_reader') THEN
        CREATE ROLE telemetry_reader LOGIN PASSWORD NULL;  -- password set at deploy time
    END IF;
END $$;

GRANT USAGE ON SCHEMA telemetry TO telemetry_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA telemetry TO telemetry_reader;

-- Telemetry admin — used for maintenance (partition creation, retention)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'telemetry_admin') THEN
        CREATE ROLE telemetry_admin LOGIN PASSWORD NULL;  -- password set at deploy time
    END IF;
END $$;

GRANT ALL ON SCHEMA telemetry TO telemetry_admin;
GRANT ALL ON ALL TABLES IN SCHEMA telemetry TO telemetry_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA telemetry TO telemetry_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA telemetry TO telemetry_admin;

-- Apply default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA telemetry
    GRANT INSERT ON TABLES TO telemetry_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA telemetry
    GRANT SELECT ON TABLES TO telemetry_reader;

COMMIT;
