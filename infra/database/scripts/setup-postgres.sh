#!/bin/bash
# Installs and configures PostgreSQL for telemetry persistence
# Run on ST-Gabriel (Linux partition) — the telemetry aggregation point
set -euo pipefail

DB_NAME="${1:-openclaw_telemetry}"
DB_PORT="${2:-5432}"
MIGRATIONS_DIR="infra/database/migrations"

echo "=== PostgreSQL Setup for AgenticOS ==="

# 1. Install PostgreSQL
echo "[1/5] Installing PostgreSQL..."
if ! command -v psql &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    echo "  Installed PostgreSQL $(psql --version | head -1)"
else
    echo "  PostgreSQL already installed: $(psql --version | head -1)"
fi

# 2. Start and enable PostgreSQL
echo "[2/5] Starting PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql
echo "  PostgreSQL running on port $DB_PORT"

# 3. Create database
echo "[3/5] Creating database '$DB_NAME'..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    sudo -u postgres createdb "$DB_NAME"
echo "  Database '$DB_NAME' ready"

# 4. Run migrations
echo "[4/5] Running migrations..."
for migration in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
    echo "  Applying: $(basename "$migration")"
    sudo -u postgres psql -d "$DB_NAME" -f "$migration"
done
echo "  All migrations applied"

# 5. Set role passwords (interactive)
echo "[5/5] Setting role passwords..."
echo "  Set passwords for database roles:"
echo "  (These should be stored securely — NOT in this repo)"
echo ""
read -sp "  Password for telemetry_writer: " WRITER_PASS
echo ""
sudo -u postgres psql -d "$DB_NAME" -c "ALTER ROLE telemetry_writer PASSWORD '$WRITER_PASS';"

read -sp "  Password for telemetry_reader: " READER_PASS
echo ""
sudo -u postgres psql -d "$DB_NAME" -c "ALTER ROLE telemetry_reader PASSWORD '$READER_PASS';"

read -sp "  Password for telemetry_admin: " ADMIN_PASS
echo ""
sudo -u postgres psql -d "$DB_NAME" -c "ALTER ROLE telemetry_admin PASSWORD '$ADMIN_PASS';"

echo ""
echo "=== PostgreSQL Setup Complete ==="
echo ""
echo "Connection details:"
echo "  Host:     localhost"
echo "  Port:     $DB_PORT"
echo "  Database: $DB_NAME"
echo "  Schema:   telemetry"
echo ""
echo "Roles:"
echo "  telemetry_writer  — for OTel Collector / exporters (INSERT only)"
echo "  telemetry_reader  — for Grafana dashboards (SELECT only)"
echo "  telemetry_admin   — for maintenance (partition creation, retention)"
echo ""
echo "Next steps:"
echo "  1. Configure Grafana PostgreSQL data source (use telemetry_reader)"
echo "  2. Configure OTel Collector PostgreSQL exporter (use telemetry_writer)"
echo "  3. Set up pg_cron for monthly partition creation:"
echo "     SELECT telemetry.create_monthly_partitions(3);"
echo "  4. Set up pg_cron for retention enforcement:"
echo "     SELECT telemetry.enforce_retention(12);"
