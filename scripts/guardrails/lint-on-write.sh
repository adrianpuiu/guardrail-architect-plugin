#!/usr/bin/env bash
# ============================================================================
# 🛡️ GUARDRAIL HOOK: Lint on Write (preToolUse → write_file)
# Catches lint issues DURING generation, not after PR.
# Exit 0 = allow write | Non-zero = block write.
# ============================================================================

FILE="$1"
[ -z "$FILE" ] && exit 0

EXT="${FILE##*.}"

# Skip non-code files
case "$EXT" in
    md|txt|json|yml|yaml|toml|cfg|ini|lock|svg|png|jpg|gif|ico|woff|woff2|eot|ttf) exit 0 ;;
esac

# ── Python ───────────────────────────────────────────────────────────────
if [ "$EXT" = "py" ]; then
    if command -v ruff &>/dev/null; then
        OUTPUT=$(ruff check "$FILE" 2>&1)
        if [ $? -ne 0 ]; then
            echo "🛡️ [GUARDRAIL] Lint issues in $FILE:"
            echo "$OUTPUT" | head -15
            ruff check --fix "$FILE" 2>/dev/null
            ruff format "$FILE" 2>/dev/null
            ruff check "$FILE" 2>/dev/null
            exit $?
        fi
    fi
fi

# ── TypeScript/JavaScript ────────────────────────────────────────────────
if [ "$EXT" = "ts" ] || [ "$EXT" = "tsx" ] || [ "$EXT" = "js" ] || [ "$EXT" = "jsx" ]; then
    if [ -f "node_modules/.bin/eslint" ]; then
        OUTPUT=$(npx eslint "$FILE" 2>&1)
        if [ $? -ne 0 ]; then
            echo "🛡️ [GUARDRAIL] Lint issues in $FILE:"
            echo "$OUTPUT" | head -15
            npx eslint --fix "$FILE" 2>/dev/null
            npx eslint "$FILE" 2>/dev/null
            exit $?
        fi
    fi
fi

# ── Go ───────────────────────────────────────────────────────────────────
if [ "$EXT" = "go" ]; then
    if command -v gofmt &>/dev/null; then
        gofmt -l "$FILE" 2>&1 | head -5
    fi
    if command -v golangci-lint &>/dev/null; then
        golangci-lint run "$FILE" 2>&1 | head -10
        exit $?
    fi
fi

# ── Rust ─────────────────────────────────────────────────────────────────
if [ "$EXT" = "rs" ]; then
    if command -v rustfmt &>/dev/null; then
        rustfmt --check "$FILE" 2>&1 | head -10
        exit $?
    fi
fi

# ── Java ─────────────────────────────────────────────────────────────────
if [ "$EXT" = "java" ]; then
    if command -v checkstyle &>/dev/null && [ -f "checkstyle.xml" ]; then
        checkstyle -c checkstyle.xml "$FILE" 2>&1 | head -10
    fi
fi

# ── C# ──────────────────────────────────────────────────────────────────
if [ "$EXT" = "cs" ]; then
    if command -v dotnet &>/dev/null; then
        dotnet format --include "$FILE" --verify-no-changes 2>&1 | head -10
    fi
fi

exit 0
