#!/bin/bash
# Validates all SKILL.md files have correct YAML frontmatter
set -euo pipefail

SCHEMA="infra/ci/schemas/skill-schema.json"
SKILLS_DIR=".claude/skills"
FAIL=0

echo "=== Validating Skill Definitions ==="

for skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue

  skill_file="${skill_dir}SKILL.md"

  if [ ! -f "$skill_file" ]; then
    echo "  WARN: Directory $skill_dir has no SKILL.md"
    continue
  fi

  echo "  Checking: $skill_file"

  # Extract YAML frontmatter
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')

  if [ -z "$frontmatter" ]; then
    echo "    FAIL: No YAML frontmatter found"
    FAIL=1
    continue
  fi

  tmpfile=$(mktemp /tmp/skill-frontmatter-XXXXXX.yml)
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
  echo "=== SKILL VALIDATION FAILED ==="
  exit 1
else
  echo ""
  echo "=== SKILL VALIDATION PASSED ==="
fi
