#!/bin/bash
# Tests that validators correctly accept valid fixtures and reject invalid ones
set -euo pipefail

PASS=0
FAIL=0

echo "=== Integration Tests: Fixture Validation ==="

# Helper function
expect_pass() {
  local desc="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (expected pass, got fail)"
    ((FAIL++))
  fi
}

expect_fail() {
  local desc="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  FAIL: $desc (expected fail, got pass)"
    ((FAIL++))
  else
    echo "  PASS: $desc (correctly rejected)"
    ((PASS++))
  fi
}

# Test valid fixtures
if command -v check-jsonschema &> /dev/null; then
  # Extract and validate valid agent
  frontmatter=$(sed -n '/^---$/,/^---$/p' infra/test/fixtures/valid-agent.md | sed '1d;$d')
  tmpfile=$(mktemp)
  echo "$frontmatter" > "$tmpfile"
  expect_pass "Valid agent passes schema" check-jsonschema --schemafile infra/ci/schemas/agent-schema.json "$tmpfile"
  rm -f "$tmpfile"

  # Extract and validate valid skill
  frontmatter=$(sed -n '/^---$/,/^---$/p' infra/test/fixtures/valid-skill.md | sed '1d;$d')
  tmpfile=$(mktemp)
  echo "$frontmatter" > "$tmpfile"
  expect_pass "Valid skill passes schema" check-jsonschema --schemafile infra/ci/schemas/skill-schema.json "$tmpfile"
  rm -f "$tmpfile"

  # Extract and validate invalid skill (should fail)
  frontmatter=$(sed -n '/^---$/,/^---$/p' infra/test/fixtures/invalid-skill.md | sed '1d;$d')
  tmpfile=$(mktemp)
  echo "$frontmatter" > "$tmpfile"
  expect_fail "Invalid skill rejected by schema" check-jsonschema --schemafile infra/ci/schemas/skill-schema.json "$tmpfile"
  rm -f "$tmpfile"

  # Validate NemoClaw policy
  expect_pass "Valid NemoClaw policy passes schema" check-jsonschema --schemafile infra/ci/schemas/nemoclaw-policy-schema.json infra/test/fixtures/valid-nemoclaw-policy.yml

  # Validate hooks.json
  expect_pass "hooks.json passes schema" check-jsonschema --schemafile infra/ci/schemas/hooks-schema.json .claude/hooks/hooks.json
else
  echo "  SKIP: check-jsonschema not installed"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -ne 0 ]; then
  echo "=== INTEGRATION TESTS FAILED ==="
  exit 1
else
  echo "=== INTEGRATION TESTS PASSED ==="
fi
