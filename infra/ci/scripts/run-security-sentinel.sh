#!/bin/bash
# CI-mode security scanning — scans ALL files, not just staged
set -euo pipefail

FAIL=0

echo "=== Security Sentinel CI Scan ==="

# 1. Scan for hardcoded secrets in all tracked files
echo "[1/6] Scanning for hardcoded secrets..."
PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  'sk-[a-zA-Z0-9]{48}'
  'sk-ant-[a-zA-Z0-9-]{90,}'
  'ghp_[a-zA-Z0-9]{36}'
  'glpat-[a-zA-Z0-9-]{20}'
  'xox[bpoa]-[a-zA-Z0-9-]+'
  'PRIVATE KEY'
)

for pattern in "${PATTERNS[@]}"; do
  MATCHES=$(grep -rlP "$pattern" --include="*.ts" --include="*.js" --include="*.json" --include="*.yml" --include="*.yaml" --include="*.md" --include="*.sh" --include="*.env" . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | grep -v "security-check.sh" | grep -v "run-security-sentinel.sh" || true)
  if [ -n "$MATCHES" ]; then
    echo "  CRITICAL: Secret pattern '$pattern' found in:"
    echo "$MATCHES" | sed 's/^/    /'
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "  OK — no secrets detected"

# 2. Scan for dangerous code patterns
echo "[2/6] Scanning for dangerous code patterns..."
DANGEROUS_PATTERNS=(
  'eval\s*\('
  'exec\s*\('
  'Function\s*\('
  '__proto__'
  'constructor\s*\['
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  MATCHES=$(grep -rlP "$pattern" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" || true)
  if [ -n "$MATCHES" ]; then
    echo "  WARN: Dangerous pattern '$pattern' found in:"
    echo "$MATCHES" | sed 's/^/    /'
  fi
done

# 3. Check for sensitive files in repo
echo "[3/6] Checking for sensitive files..."
SENSITIVE=$(find . -type f \( -name "*.env" -o -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" -o -name "*.keystore" -o -name "*.credentials" \) -not -path "./.git/*" 2>/dev/null || true)
if [ -n "$SENSITIVE" ]; then
  echo "  CRITICAL: Sensitive files found in repo:"
  echo "$SENSITIVE" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK — no sensitive files"
fi

# 4. Verify .gitignore covers sensitive patterns
echo "[4/6] Checking .gitignore coverage..."
if [ -f ".gitignore" ]; then
  MISSING_PATTERNS=()
  for pattern in ".env" "*.pem" "*.key" "node_modules"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
      MISSING_PATTERNS+=("$pattern")
    fi
  done
  if [ ${#MISSING_PATTERNS[@]} -gt 0 ]; then
    echo "  WARN: .gitignore missing patterns: ${MISSING_PATTERNS[*]}"
  else
    echo "  OK — .gitignore covers sensitive patterns"
  fi
else
  echo "  WARN: No .gitignore file found"
fi

# 5. Check NemoClaw policies for deny-all baseline
echo "[5/6] Checking NemoClaw policies..."
POLICY_FILES=$(find . -name "*.yml" -o -name "*.yaml" | xargs grep -l "baseline:" 2>/dev/null | grep -v ".git/" || true)
if [ -n "$POLICY_FILES" ]; then
  for policy in $POLICY_FILES; do
    if ! grep -q "baseline: deny-all" "$policy" 2>/dev/null; then
      echo "  HIGH: Policy $policy does not use deny-all baseline"
      FAIL=1
    else
      echo "  OK — $policy uses deny-all baseline"
    fi
  done
else
  echo "  SKIP — no NemoClaw policy files found yet"
fi

# 6. npm audit if applicable
echo "[6/6] Checking dependency vulnerabilities..."
if [ -f "package-lock.json" ]; then
  AUDIT_RESULT=$(npm audit --json 2>/dev/null || true)
  CRITICAL=$(echo "$AUDIT_RESULT" | grep -oP '"critical":\s*\K\d+' || echo "0")
  HIGH=$(echo "$AUDIT_RESULT" | grep -oP '"high":\s*\K\d+' || echo "0")
  if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo "  HIGH: npm audit found $CRITICAL critical and $HIGH high vulnerabilities"
    FAIL=1
  else
    echo "  OK — no critical/high vulnerabilities"
  fi
else
  echo "  SKIP — no package-lock.json"
fi

echo ""
if [ $FAIL -ne 0 ]; then
  echo "=== SECURITY SCAN FAILED ==="
  exit 1
else
  echo "=== SECURITY SCAN PASSED ==="
fi
