#!/usr/bin/env bash
# ============================================================================
# 🛡️ GUARDRAIL HOOK: Test on Write (postToolUse → write_file)
# Runs tests related to the changed file — immediate feedback.
# Always exits 0 — test failures are warnings, not write blockers.
# ============================================================================

FILE="$1"
[ -z "$FILE" ] && exit 0

EXT="${FILE##*.}"

# Skip non-code and test files themselves
case "$EXT" in
    md|txt|json|yml|yaml|toml|cfg|ini|lock) exit 0 ;;
esac

# ── Python ───────────────────────────────────────────────────────────────
if [ "$EXT" = "py" ]; then
    # Don't re-run if the file IS a test
    [[ "$FILE" == *"test_"* ]] || [[ "$FILE" == *"_test.py" ]] && {
        echo "🧪 [GUARDRAIL] Running changed test: $FILE"
        python -m pytest "$FILE" -x --tb=short -q 2>&1 | tail -8
        exit 0
    }

    # Strategy 1: tests/path/test_module.py
    TEST1=$(echo "$FILE" | sed 's|^src/|tests/|' | sed 's|\([^/]*\)\.py$|test_\1.py|')
    # Strategy 2: tests/path/module_test.py
    TEST2=$(echo "$FILE" | sed 's|^src/|tests/|' | sed 's|\.py$|_test.py|')
    # Strategy 3: same dir test file
    TEST3=$(dirname "$FILE")/test_$(basename "$FILE")

    for TEST in "$TEST1" "$TEST2" "$TEST3"; do
        if [ -f "$TEST" ]; then
            echo "🧪 [GUARDRAIL] Running: $TEST"
            python -m pytest "$TEST" -x --tb=short -q 2>&1 | tail -8
            exit 0
        fi
    done
fi

# ── TypeScript/JavaScript ────────────────────────────────────────────────
if [ "$EXT" = "ts" ] || [ "$EXT" = "tsx" ] || [ "$EXT" = "js" ] || [ "$EXT" = "jsx" ]; then
    # Vitest: related file detection
    if [ -f "node_modules/.bin/vitest" ]; then
        echo "🧪 [GUARDRAIL] Running related tests for $FILE"
        npx vitest related "$FILE" --run 2>&1 | tail -8
        exit 0
    fi
    # Jest: find matching test
    if [ -f "node_modules/.bin/jest" ]; then
        TEST=$(echo "$FILE" | sed "s|\.\(tsx\?\)$|.test.\1|")
        [ -f "$TEST" ] && {
            echo "🧪 [GUARDRAIL] Running: $TEST"
            npx jest "$TEST" --no-coverage 2>&1 | tail -8
            exit 0
        }
    fi
fi

# ── Go ───────────────────────────────────────────────────────────────────
if [ "$EXT" = "go" ] && [[ "$FILE" != *"_test.go" ]]; then
    DIR=$(dirname "$FILE")
    echo "🧪 [GUARDRAIL] Running tests in $DIR"
    go test "./$DIR/..." -count=1 -short 2>&1 | tail -8
fi

# ── Rust ─────────────────────────────────────────────────────────────────
if [ "$EXT" = "rs" ]; then
    echo "🧪 [GUARDRAIL] Running cargo test"
    cargo test --quiet 2>&1 | tail -8
fi

# ── Java ─────────────────────────────────────────────────────────────────
if [ "$EXT" = "java" ]; then
    CLASS=$(basename "$FILE" .java)
    if [[ "$CLASS" != *"Test" ]]; then
        TEST_CLASS="${CLASS}Test"
        echo "🧪 [GUARDRAIL] Running: $TEST_CLASS"
        if [ -f "gradlew" ]; then
            ./gradlew test --tests "*${TEST_CLASS}" 2>&1 | tail -8
        elif [ -f "mvnw" ] || command -v mvn &>/dev/null; then
            mvn test -Dtest="${TEST_CLASS}" -pl . 2>&1 | tail -8
        fi
    fi
fi

# ── C# ──────────────────────────────────────────────────────────────────
if [ "$EXT" = "cs" ]; then
    CLASS=$(basename "$FILE" .cs)
    if [[ "$CLASS" != *"Test"* ]]; then
        echo "🧪 [GUARDRAIL] Running tests matching: $CLASS"
        dotnet test --filter "FullyQualifiedName~${CLASS}" --no-build 2>&1 | tail -8
    fi
fi

exit 0
