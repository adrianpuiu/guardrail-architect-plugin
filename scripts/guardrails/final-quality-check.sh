#!/usr/bin/env bash
# ============================================================================
# 🛡️ GUARDRAIL HOOK: Final Quality Check (sessionEnd)
# Comprehensive sweep before session closes. Nothing slips through.
# ============================================================================

echo ""
echo "🛡️ ╔══════════════════════════════════════════════════╗"
echo "   ║          FINAL QUALITY CHECK                     ║"
echo "   ╚══════════════════════════════════════════════════╝"
echo ""

PASS=0; FAIL=0; WARN=0; SKIP=0

result_pass() { echo "   ✅ $1"; PASS=$((PASS+1)); }
result_fail() { echo "   ❌ $1"; FAIL=$((FAIL+1)); }
result_warn() { echo "   ⚠️  $1"; WARN=$((WARN+1)); }
result_skip() { echo "   ⏭️  $1 (not configured)"; SKIP=$((SKIP+1)); }

# ── What changed this session? ───────────────────────────────────────────
TOTAL_CHANGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
echo "   📝 $TOTAL_CHANGED unstaged, $STAGED staged changes"
echo ""

# ── Detect language from changed files ───────────────────────────────────
HAS_PY=$(git diff --name-only -- '*.py' 2>/dev/null | head -1)
HAS_TS=$(git diff --name-only -- '*.ts' '*.tsx' 2>/dev/null | head -1)
HAS_JS=$(git diff --name-only -- '*.js' '*.jsx' 2>/dev/null | head -1)
HAS_GO=$(git diff --name-only -- '*.go' 2>/dev/null | head -1)
HAS_RS=$(git diff --name-only -- '*.rs' 2>/dev/null | head -1)
HAS_JAVA=$(git diff --name-only -- '*.java' 2>/dev/null | head -1)
HAS_CS=$(git diff --name-only -- '*.cs' 2>/dev/null | head -1)

# ── 1. LINT ──────────────────────────────────────────────────────────────
echo "   [1/5] Linting..."
LINT_DONE=false
if [ -n "$HAS_PY" ] && command -v ruff &>/dev/null; then
    ruff check . 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Lint (ruff)" || result_fail "Lint (ruff) — errors found"
    LINT_DONE=true
fi
if [ -n "$HAS_TS$HAS_JS" ] && [ -f "node_modules/.bin/eslint" ]; then
    npx eslint . 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Lint (eslint)" || result_fail "Lint (eslint) — errors found"
    LINT_DONE=true
fi
if [ -n "$HAS_GO" ] && command -v golangci-lint &>/dev/null; then
    golangci-lint run ./... 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Lint (golangci-lint)" || result_fail "Lint (golangci-lint)"
    LINT_DONE=true
fi
if [ -n "$HAS_RS" ] && command -v cargo &>/dev/null; then
    cargo clippy -- -D warnings 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Lint (clippy)" || result_fail "Lint (clippy)"
    LINT_DONE=true
fi
$LINT_DONE || result_skip "Lint"

# ── 2. TYPE CHECK ────────────────────────────────────────────────────────
echo "   [2/5] Type checking..."
TYPE_DONE=false
if [ -n "$HAS_PY" ] && command -v mypy &>/dev/null; then
    mypy src/ --strict --ignore-missing-imports 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Types (mypy)" || result_fail "Types (mypy) — errors found"
    TYPE_DONE=true
fi
if [ -n "$HAS_TS" ] && [ -f "tsconfig.json" ]; then
    npx tsc --noEmit 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Types (tsc)" || result_fail "Types (tsc) — errors found"
    TYPE_DONE=true
fi
if [ -n "$HAS_GO" ]; then
    go build ./... 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Types (go build)" || result_fail "Types (go build)"
    TYPE_DONE=true
fi
if [ -n "$HAS_RS" ]; then
    cargo check 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Types (rustc)" || result_fail "Types (rustc)"
    TYPE_DONE=true
fi
$TYPE_DONE || result_skip "Types"

# ── 3. TESTS ─────────────────────────────────────────────────────────────
echo "   [3/5] Running tests..."
TEST_DONE=false
if command -v pytest &>/dev/null && [ -d "tests" ]; then
    python -m pytest tests/ -x --tb=short -q 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (pytest)" || result_fail "Tests (pytest) — failures"
    TEST_DONE=true
elif [ -f "node_modules/.bin/vitest" ]; then
    npx vitest --run 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (vitest)" || result_fail "Tests (vitest)"
    TEST_DONE=true
elif [ -f "node_modules/.bin/jest" ]; then
    npx jest --no-coverage 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (jest)" || result_fail "Tests (jest)"
    TEST_DONE=true
elif [ -n "$HAS_GO" ]; then
    go test ./... -short -count=1 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (go test)" || result_fail "Tests (go test)"
    TEST_DONE=true
elif [ -n "$HAS_RS" ]; then
    cargo test --quiet 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (cargo test)" || result_fail "Tests (cargo test)"
    TEST_DONE=true
elif [ -f "gradlew" ]; then
    ./gradlew test 2>&1 | tail -5
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Tests (gradle)" || result_fail "Tests (gradle)"
    TEST_DONE=true
fi
$TEST_DONE || result_skip "Tests"

# ── 4. ARCHITECTURE ─────────────────────────────────────────────────────
echo "   [4/5] Architecture..."
ARCH_DONE=false
if command -v lint-imports &>/dev/null && grep -q "importlinter" pyproject.toml 2>/dev/null; then
    lint-imports 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Arch (import-linter)" || result_fail "Arch (import-linter) — violations"
    ARCH_DONE=true
fi
if [ -f ".dependency-cruiser.cjs" ] || [ -f ".dependency-cruiser.mjs" ]; then
    CFG=$(ls .dependency-cruiser.cjs .dependency-cruiser.mjs 2>/dev/null | head -1)
    npx depcruise src --config "$CFG" --output-type err 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Arch (dependency-cruiser)" || result_fail "Arch (dependency-cruiser)"
    ARCH_DONE=true
fi
$ARCH_DONE || result_skip "Architecture"

# ── 5. SECURITY ──────────────────────────────────────────────────────────
echo "   [5/5] Security..."
SEC_DONE=false
if [ -n "$HAS_PY" ] && command -v bandit &>/dev/null; then
    bandit -r src/ -q 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Security (bandit)" || result_warn "Security (bandit) — issues found"
    SEC_DONE=true
fi
if [ -f "package.json" ] && command -v npm &>/dev/null; then
    npm audit --audit-level=high 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Security (npm audit)" || result_warn "Security (npm audit)"
    SEC_DONE=true
fi
if [ -n "$HAS_RS" ] && command -v cargo-audit &>/dev/null; then
    cargo audit 2>&1 | tail -3
    [ ${PIPESTATUS[0]:-$?} -eq 0 ] && result_pass "Security (cargo audit)" || result_warn "Security (cargo audit)"
    SEC_DONE=true
fi
$SEC_DONE || result_skip "Security"

# ── SUMMARY ──────────────────────────────────────────────────────────────
echo ""
echo "   ══════════════════════════════════════════════════"
TOTAL=$((PASS+FAIL+WARN))
if [ $FAIL -eq 0 ]; then
    echo "   ✅ ${PASS} passed, ${WARN} warnings, ${SKIP} skipped — SAFE TO COMMIT"
else
    echo "   ❌ ${FAIL} FAILED, ${PASS} passed, ${WARN} warnings"
    echo "      Fix issues before committing. Run /guardrail:fix"
fi
echo "   ══════════════════════════════════════════════════"

exit $FAIL
