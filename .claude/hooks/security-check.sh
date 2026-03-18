#!/bin/bash
# Security pre-commit checks
# Run as part of git pre-commit hook or manually

set -euo pipefail

FAIL=0

echo "=== Security Sentinel Pre-Commit Checks ==="

# 1. Check for hardcoded secrets
echo "[1/5] Scanning for hardcoded secrets..."
PATTERNS=(
  'AKIA[0-9A-Z]{16}'           # AWS Access Key
  'sk-[a-zA-Z0-9]{48}'         # OpenAI API Key
  'sk-ant-[a-zA-Z0-9-]{90,}'   # Anthropic API Key
  'ghp_[a-zA-Z0-9]{36}'        # GitHub Personal Access Token
  'glpat-[a-zA-Z0-9-]{20}'     # GitLab Personal Access Token
  'xox[bpoa]-[a-zA-Z0-9-]+'    # Slack Token
  'PRIVATE KEY'                  # Private keys
  'password\s*=\s*["\x27][^"\x27]+'  # Hardcoded passwords
)

for pattern in "${PATTERNS[@]}"; do
  if git diff --cached --diff-filter=ACMR -U0 | grep -qiP "$pattern" 2>/dev/null; then
    echo "  CRITICAL: Potential secret detected matching pattern: $pattern"
    FAIL=1
  fi
done

if [ $FAIL -eq 0 ]; then echo "  OK — no secrets detected"; fi

# 2. Check for dangerous functions
echo "[2/5] Scanning for dangerous code patterns..."
DANGEROUS=(
  'eval\s*('
  'exec\s*('
  'Function\s*('
  'child_process'
  '__proto__'
  'constructor\s*\['
)

for pattern in "${DANGEROUS[@]}"; do
  MATCHES=$(git diff --cached --diff-filter=ACMR -U0 | grep -cP "$pattern" 2>/dev/null || true)
  if [ "$MATCHES" -gt 0 ]; then
    echo "  WARN: Found $MATCHES occurrence(s) of dangerous pattern: $pattern"
  fi
done

# 3. Check for new dependencies with postinstall scripts
echo "[3/5] Checking for suspicious package scripts..."
if git diff --cached --name-only | grep -q "package.json"; then
  if git diff --cached -- package.json | grep -qP '"(preinstall|postinstall|preuninstall)"'; then
    echo "  HIGH: New install scripts detected in package.json — review manually!"
    FAIL=1
  else
    echo "  OK — no suspicious install scripts"
  fi
else
  echo "  OK — no package.json changes"
fi

# 4. Check for .env or key files being committed
echo "[4/5] Checking for sensitive files..."
SENSITIVE_FILES=$(git diff --cached --name-only --diff-filter=A | grep -iE '\.(env|pem|key|p12|pfx|keystore|jks|credentials|secret)$' || true)
if [ -n "$SENSITIVE_FILES" ]; then
  echo "  CRITICAL: Sensitive files staged for commit:"
  echo "$SENSITIVE_FILES" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK — no sensitive files staged"
fi

# 5. Run npm audit if package-lock.json exists
echo "[5/5] Checking dependency vulnerabilities..."
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
  echo "  SKIP — no package-lock.json found"
fi

echo ""
if [ $FAIL -ne 0 ]; then
  echo "=== SECURITY CHECK FAILED — review findings above ==="
  exit 1
else
  echo "=== SECURITY CHECK PASSED ==="
  exit 0
fi
