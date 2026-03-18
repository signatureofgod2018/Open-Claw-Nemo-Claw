#!/bin/bash
# Validates all agent .md files have correct YAML frontmatter
set -euo pipefail

SCHEMA="infra/ci/schemas/agent-schema.json"
AGENTS_DIR=".claude/agents"
FAIL=0

echo "=== Validating Agent Definitions ==="

for agent_file in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_file" ] || continue
  [ "$(basename "$agent_file")" = ".gitkeep" ] && continue

  echo "  Checking: $agent_file"

  # Extract YAML frontmatter (between --- delimiters)
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$agent_file" | sed '1d;$d')

  if [ -z "$frontmatter" ]; then
    echo "    FAIL: No YAML frontmatter found"
    FAIL=1
    continue
  fi

  # Write frontmatter to temp file and validate against schema
  tmpfile=$(mktemp /tmp/agent-frontmatter-XXXXXX.yml)
  echo "$frontmatter" > "$tmpfile"

  if check-jsonschema --schemafile "$SCHEMA" "$tmpfile" 2>/dev/null; then
    echo "    PASS"
  else
    echo "    FAIL: Frontmatter does not match schema"
    check-jsonschema --schemafile "$SCHEMA" "$tmpfile" 2>&1 | sed 's/^/    /'
    FAIL=1
  fi

  rm -f "$tmpfile"
done

if [ $FAIL -ne 0 ]; then
  echo ""
  echo "=== AGENT VALIDATION FAILED ==="
  exit 1
else
  echo ""
  echo "=== AGENT VALIDATION PASSED ==="
fi
