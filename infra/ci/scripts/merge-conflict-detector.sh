#!/bin/bash
# Detects structural conflicts when merging project spaces
set -euo pipefail

FAIL=0

echo "=== Merge Safety: Structural Conflict Detection ==="

# 1. Check for duplicate agent names
echo "[1/4] Checking for duplicate agent names..."
AGENT_NAMES=$(find .claude/agents -name "*.md" -not -name ".gitkeep" -exec sed -n 's/^name:\s*//p' {} \; 2>/dev/null | sort)
DUPES=$(echo "$AGENT_NAMES" | uniq -d)
if [ -n "$DUPES" ]; then
  echo "  FAIL: Duplicate agent names found:"
  echo "$DUPES" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK — no duplicate agent names"
fi

# 2. Check for duplicate skill names
echo "[2/4] Checking for duplicate skill names..."
SKILL_NAMES=$(find .claude/skills -name "SKILL.md" -exec sed -n 's/^name:\s*//p' {} \; 2>/dev/null | sort)
DUPES=$(echo "$SKILL_NAMES" | uniq -d)
if [ -n "$DUPES" ]; then
  echo "  FAIL: Duplicate skill names found:"
  echo "$DUPES" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK — no duplicate skill names"
fi

# 3. Check for conflicting hook configurations
echo "[3/4] Checking for hook config conflicts..."
HOOK_FILES=$(find . -name "hooks.json" -not -path "./.git/*" 2>/dev/null)
HOOK_COUNT=$(echo "$HOOK_FILES" | grep -c . || true)
if [ "$HOOK_COUNT" -gt 1 ]; then
  echo "  WARN: Multiple hooks.json files found — may need manual merge:"
  echo "$HOOK_FILES" | sed 's/^/    /'
else
  echo "  OK — single hooks.json"
fi

# 4. Check for NemoClaw policy conflicts (weakened baselines)
echo "[4/4] Checking NemoClaw policy integrity..."
POLICY_FILES=$(find . -name "*.yml" -o -name "*.yaml" 2>/dev/null | xargs grep -l "baseline:" 2>/dev/null | grep -v ".git/" || true)
if [ -n "$POLICY_FILES" ]; then
  for policy in $POLICY_FILES; do
    if ! grep -q "baseline: deny-all" "$policy" 2>/dev/null; then
      echo "  FAIL: Merged policy $policy weakens deny-all baseline"
      FAIL=1
    fi
  done
  echo "  OK — all policies maintain deny-all baseline"
else
  echo "  SKIP — no NemoClaw policies to check"
fi

echo ""
if [ $FAIL -ne 0 ]; then
  echo "=== MERGE SAFETY CHECK FAILED ==="
  exit 1
else
  echo "=== MERGE SAFETY CHECK PASSED ==="
fi
