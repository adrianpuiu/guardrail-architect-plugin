#!/usr/bin/env bash
# ============================================================================
# 🛡️ GUARDRAIL HOOK: Load Architecture Context (sessionStart)
# Injects architecture rules into agent context from line 1.
# ============================================================================

echo "🛡️ ═══════════════════════════════════════════════════════"
echo "   GUARDRAIL ARCHITECT — Session Initialized"
echo "   ═══════════════════════════════════════════════════════"
echo ""

# ── Show architecture section from CLAUDE.md ─────────────────────────────
if [ -f "CLAUDE.md" ]; then
    if grep -q "## Architecture" CLAUDE.md; then
        echo "📐 Architecture rules (from CLAUDE.md):"
        echo "   ─────────────────────────────────────"
        sed -n '/## Architecture/,/^## [^A]/p' CLAUDE.md | head -40 | sed 's/^/   /'
        echo ""
    fi
fi

# ── Python: import-linter status ─────────────────────────────────────────
if [ -f "pyproject.toml" ] && grep -q "importlinter" pyproject.toml 2>/dev/null; then
    echo "🏗️  Import-linter contracts:"
    grep 'name = ' pyproject.toml | sed 's/.*= "/   → /;s/"//'
    if command -v lint-imports &>/dev/null; then
        if lint-imports 2>&1 >/dev/null; then
            echo "   ✅ All contracts passing"
        else
            echo "   ❌ Violations detected — run /guardrail:arch-check"
        fi
    fi
    echo ""
fi

# ── TypeScript: dependency-cruiser status ────────────────────────────────
if [ -f ".dependency-cruiser.cjs" ] || [ -f ".dependency-cruiser.mjs" ]; then
    echo "🏗️  dependency-cruiser rules active"
    if command -v npx &>/dev/null && [ -d "node_modules" ]; then
        CFG=$(ls .dependency-cruiser.cjs .dependency-cruiser.mjs 2>/dev/null | head -1)
        if npx depcruise src --config "$CFG" --output-type err 2>&1 >/dev/null; then
            echo "   ✅ All dependency rules passing"
        else
            echo "   ❌ Violations detected — run /guardrail:arch-check"
        fi
    fi
    echo ""
fi

# ── Java: ArchUnit status ────────────────────────────────────────────────
ARCH_JAVA=$(find . -maxdepth 5 -name "*Arch*Test.java" -o -name "*Architecture*Test.java" 2>/dev/null | head -1)
if [ -n "$ARCH_JAVA" ]; then
    echo "🏗️  ArchUnit tests: $ARCH_JAVA"
    echo ""
fi

# ── Go: go-arch-lint status ──────────────────────────────────────────────
if [ -f ".go-arch-lint.yml" ]; then
    echo "🏗️  go-arch-lint configured"
    if command -v go-arch-lint &>/dev/null; then
        if go-arch-lint check 2>&1 >/dev/null; then
            echo "   ✅ All rules passing"
        else
            echo "   ❌ Violations detected"
        fi
    fi
    echo ""
fi

# ── Rust: cargo-deny status ──────────────────────────────────────────────
if [ -f "deny.toml" ]; then
    echo "🏗️  cargo-deny configured"
    echo ""
fi

# ── C#: ArchUnitNET status ───────────────────────────────────────────────
ARCH_CS=$(find . -maxdepth 5 -name "*Architecture*Tests.cs" 2>/dev/null | head -1)
if [ -n "$ARCH_CS" ]; then
    echo "🏗️  ArchUnitNET tests: $ARCH_CS"
    echo ""
fi

# ── Active hooks reminder ───────────────────────────────────────────────
echo "🛡️  Active guardrail hooks:"
echo "   • preToolUse  → lint every file before write"
echo "   • postToolUse → run related tests after write"
echo "   • sessionEnd  → full quality sweep"
echo ""
echo "   Commands: /guardrail:assess :generate :review :fix :arch-check :status"
echo "═══════════════════════════════════════════════════════════"
