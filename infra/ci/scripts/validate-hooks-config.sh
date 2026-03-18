#!/bin/bash
# Validates hooks.json against schema
set -euo pipefail

SCHEMA="infra/ci/schemas/hooks-schema.json"
HOOKS_FILE=".claude/hooks/hooks.json"

echo "=== Validating Hooks Configuration ==="

if [ ! -f "$HOOKS_FILE" ]; then
  echo "  SKIP: No hooks.json found"
  exit 0
fi

echo "  Checking: $HOOKS_FILE"

if check-jsonschema --schemafile "$SCHEMA" "$HOOKS_FILE" 2>/dev/null; then
  echo "  PASS"
  echo ""
  echo "=== HOOKS VALIDATION PASSED ==="
else
  echo "  FAIL: hooks.json does not match schema"
  check-jsonschema --schemafile "$SCHEMA" "$HOOKS_FILE" 2>&1 | sed 's/^/  /'
  echo ""
  echo "=== HOOKS VALIDATION FAILED ==="
  exit 1
fi
