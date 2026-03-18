#!/bin/bash
# Runs all pending database migrations in order
set -euo pipefail

DB_NAME="${1:-openclaw_telemetry}"
MIGRATIONS_DIR="infra/database/migrations"

echo "=== Running Database Migrations ==="
echo "Database: $DB_NAME"
echo ""

for migration in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
    filename=$(basename "$migration")
    echo "  Applying: $filename"
    sudo -u postgres psql -d "$DB_NAME" -f "$migration" 2>&1 | sed 's/^/    /'
    echo "  Done: $filename"
    echo ""
done

echo "=== All Migrations Applied ==="
