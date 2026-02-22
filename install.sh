#!/usr/bin/env bash
# ============================================================================
# 🛡️ GUARDRAIL ARCHITECT — Claude Code Plugin Installer
# ============================================================================
# Usage:
#   ./install.sh [--language python|typescript|java|go|rust|csharp]
#                [--project-root /path/to/project]
#                [--skip-hooks] [--skip-ci] [--skip-precommit]
#                [--dry-run]
# ============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

banner() {
    echo ""
    echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║           🛡️  GUARDRAIL ARCHITECT INSTALLER                 ║${NC}"
    echo -e "${PURPLE}${BOLD}║         Production guardrails for agentic coding             ║${NC}"
    echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
step()    { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }

# ── Defaults ─────────────────────────────────────────────────────────────
LANGUAGE=""
PROJECT_ROOT="$(pwd)"
SKIP_HOOKS=false
SKIP_CI=false
SKIP_PRECOMMIT=false
DRY_RUN=false
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse Arguments ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --language)       LANGUAGE="$2"; shift 2 ;;
        --project-root)   PROJECT_ROOT="$2"; shift 2 ;;
        --skip-hooks)     SKIP_HOOKS=true; shift ;;
        --skip-ci)        SKIP_CI=true; shift ;;
        --skip-precommit) SKIP_PRECOMMIT=true; shift ;;
        --dry-run)        DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTIONS]"
            echo "  --language <lang>     Force language (python|typescript|java|go|rust|csharp)"
            echo "  --project-root <path> Target project directory (default: cwd)"
            echo "  --skip-hooks          Don't install Claude Code hooks"
            echo "  --skip-ci             Don't generate CI/CD pipeline"
            echo "  --skip-precommit      Don't set up pre-commit hooks"
            echo "  --dry-run             Show what would be installed"
            exit 0 ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

banner

# ── Auto-Detect Language ─────────────────────────────────────────────────
detect_language() {
    step "Detecting project stack"
    cd "$PROJECT_ROOT"

    if [ -n "$LANGUAGE" ]; then
        info "Language forced: $LANGUAGE"; return
    fi

    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] || [ -f "Pipfile" ]; then
        LANGUAGE="python"
    elif [ -f "tsconfig.json" ]; then
        LANGUAGE="typescript"
    elif [ -f "package.json" ] && ! [ -f "tsconfig.json" ]; then
        LANGUAGE="typescript"  # default JS to TS pipeline
    elif [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        LANGUAGE="java"
    elif [ -f "go.mod" ]; then
        LANGUAGE="go"
    elif [ -f "Cargo.toml" ]; then
        LANGUAGE="rust"
    elif ls *.csproj 1>/dev/null 2>&1 || ls *.fsproj 1>/dev/null 2>&1 || ls *.sln 1>/dev/null 2>&1; then
        LANGUAGE="csharp"
    else
        warn "Could not auto-detect language."
        ls -1 2>/dev/null | head -15
        read -p "  Enter language (python/typescript/java/go/rust/csharp): " LANGUAGE
    fi

    success "Detected: ${BOLD}$LANGUAGE${NC}"
}

# ── Detect Existing Tools ────────────────────────────────────────────────
detect_existing() {
    step "Scanning existing guardrails"
    local found=0

    [ -d ".github/workflows" ]        && { info "GitHub Actions found"; found=$((found+1)); }
    [ -f ".gitlab-ci.yml" ]           && { info "GitLab CI found"; found=$((found+1)); }
    [ -f "Jenkinsfile" ]              && { info "Jenkins found"; found=$((found+1)); }

    [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.mjs" ] && { info "ESLint found"; found=$((found+1)); }
    [ -f "ruff.toml" ] || [ -f ".ruff.toml" ] && { info "Ruff found"; found=$((found+1)); }
    [ -f ".flake8" ]                  && { warn "flake8 found (consider migrating to Ruff)"; found=$((found+1)); }
    [ -f "mypy.ini" ] || grep -q "tool.mypy" pyproject.toml 2>/dev/null && { info "mypy found"; found=$((found+1)); }
    [ -f ".golangci.yml" ]            && { info "golangci-lint found"; found=$((found+1)); }
    [ -f "clippy.toml" ]              && { info "clippy found"; found=$((found+1)); }

    [ -d ".claude" ]                  && { info "Claude Code config found"; found=$((found+1)); }
    [ -f "CLAUDE.md" ]                && { info "CLAUDE.md found"; found=$((found+1)); }
    [ -f ".cursorrules" ]             && { info "Cursor rules found"; found=$((found+1)); }
    [ -f ".pre-commit-config.yaml" ]  && { info "pre-commit found"; found=$((found+1)); }
    [ -d ".husky" ]                   && { info "husky found"; found=$((found+1)); }

    [ $found -eq 0 ] && warn "No existing guardrails detected — starting from scratch"
    echo ""
}

# ── Copy helper: only if target doesn't exist ───────────────────────────
safe_copy() {
    local src="$1" dst="$2" label="$3"
    if $DRY_RUN; then
        info "[DRY RUN] Would create $dst"
        return 0
    fi
    if [ -f "$dst" ]; then
        info "$label already exists — skipping"
        return 0
    fi
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        success "Created $label"
        return 0
    else
        warn "Template not found: $src"
        return 1
    fi
}

# ── Append helper: append if section not already present ─────────────────
safe_append() {
    local src="$1" dst="$2" marker="$3" label="$4"
    if $DRY_RUN; then
        info "[DRY RUN] Would append $label to $dst"
        return 0
    fi
    if [ ! -f "$dst" ]; then
        warn "$dst does not exist — skipping append"
        return 1
    fi
    if grep -q "$marker" "$dst" 2>/dev/null; then
        info "$label already configured in $dst"
        return 0
    fi
    echo "" >> "$dst"
    cat "$src" >> "$dst"
    success "Appended $label to $dst"
}

# ── Install Claude Code Commands ─────────────────────────────────────────
install_commands() {
    step "Installing Claude Code slash commands"
    local cmd_dir="$PROJECT_ROOT/.claude/commands"
    mkdir -p "$cmd_dir"

    if $DRY_RUN; then info "[DRY RUN] Would create commands in $cmd_dir"; return; fi

    local count=0
    for f in "$PLUGIN_DIR/.claude/commands"/*.md; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        cp "$f" "$cmd_dir/$name"
        count=$((count+1))
    done

    success "Installed $count slash commands:"
    for f in "$cmd_dir"/*.md; do
        echo -e "  ${DIM}/guardrail:$(basename "$f" .md)${NC}"
    done
}

# ── Install Hook Scripts ─────────────────────────────────────────────────
install_hooks() {
    if $SKIP_HOOKS; then info "Skipping hooks (--skip-hooks)"; return; fi

    step "Installing Claude Code hooks"
    local scripts_dir="$PROJECT_ROOT/scripts/guardrails"
    local claude_dir="$PROJECT_ROOT/.claude"
    mkdir -p "$scripts_dir" "$claude_dir"

    if $DRY_RUN; then info "[DRY RUN] Would create hook scripts"; return; fi

    # Copy all hook scripts
    for f in "$PLUGIN_DIR/scripts/guardrails"/*.sh; do
        [ -f "$f" ] || continue
        cp "$f" "$scripts_dir/"
    done
    chmod +x "$scripts_dir"/*.sh
    success "Hook scripts installed ($(ls -1 "$scripts_dir"/*.sh | wc -l) files)"

    # Copy adversarial review script if present
    [ -f "$PLUGIN_DIR/scripts/guardrails/adversarial-review.py" ] && \
        cp "$PLUGIN_DIR/scripts/guardrails/adversarial-review.py" "$scripts_dir/"

    # Generate settings.json with hooks
    local settings_file="$claude_dir/settings.json"
    if [ -f "$settings_file" ]; then
        warn "settings.json exists — writing settings.guardrails.json"
        settings_file="$claude_dir/settings.guardrails.json"
    fi

    cat > "$settings_file" << 'HOOKS_EOF'
{
  "hooks": {
    "preToolUse": [
      {
        "matcher": "write_file",
        "hook": "scripts/guardrails/lint-on-write.sh"
      }
    ],
    "postToolUse": [
      {
        "matcher": "write_file",
        "hook": "scripts/guardrails/test-on-write.sh"
      }
    ],
    "sessionStart": [
      {
        "hook": "scripts/guardrails/load-architecture-context.sh"
      }
    ],
    "sessionEnd": [
      {
        "hook": "scripts/guardrails/final-quality-check.sh"
      }
    ]
  }
}
HOOKS_EOF
    success "Claude Code hooks configured"
}

# ── Language-Specific Config Generators ──────────────────────────────────

generate_python() {
    safe_copy "$PLUGIN_DIR/templates/python/ruff.toml" "$PROJECT_ROOT/ruff.toml" "ruff.toml"
    [ -f "$PROJECT_ROOT/pyproject.toml" ] && {
        safe_append "$PLUGIN_DIR/templates/python/mypy-section.toml" "$PROJECT_ROOT/pyproject.toml" "tool.mypy" "mypy config"
        safe_append "$PLUGIN_DIR/templates/python/importlinter-section.toml" "$PROJECT_ROOT/pyproject.toml" "tool.importlinter" "import-linter contracts"
    }
    ! $SKIP_PRECOMMIT && safe_copy "$PLUGIN_DIR/templates/python/pre-commit-config.yaml" "$PROJECT_ROOT/.pre-commit-config.yaml" ".pre-commit-config.yaml"
    echo ""
    info "Install: ${BOLD}pip install ruff mypy import-linter bandit pip-audit pytest pytest-cov pre-commit${NC}"
}

generate_typescript() {
    safe_copy "$PLUGIN_DIR/templates/typescript/eslint.config.mjs" "$PROJECT_ROOT/eslint.config.mjs" "eslint.config.mjs"
    safe_copy "$PLUGIN_DIR/templates/typescript/tsconfig.strict.json" "$PROJECT_ROOT/tsconfig.strict.json" "tsconfig.strict.json"
    safe_copy "$PLUGIN_DIR/templates/typescript/dependency-cruiser.cjs" "$PROJECT_ROOT/.dependency-cruiser.cjs" ".dependency-cruiser.cjs"
    if ! $SKIP_PRECOMMIT; then
        mkdir -p "$PROJECT_ROOT/.husky"
        safe_copy "$PLUGIN_DIR/templates/typescript/husky-precommit.sh" "$PROJECT_ROOT/.husky/pre-commit" ".husky/pre-commit"
        chmod +x "$PROJECT_ROOT/.husky/pre-commit" 2>/dev/null || true
    fi
    echo ""
    info "Install: ${BOLD}npm i -D eslint typescript-eslint dependency-cruiser husky lint-staged prettier${NC}"
}

generate_java() {
    safe_copy "$PLUGIN_DIR/templates/java/checkstyle.xml" "$PROJECT_ROOT/checkstyle.xml" "checkstyle.xml"
    mkdir -p "$PROJECT_ROOT/src/test/java/arch"
    safe_copy "$PLUGIN_DIR/templates/java/ArchitectureTest.java" "$PROJECT_ROOT/src/test/java/arch/ArchitectureTest.java" "ArchUnit test"
    ! $SKIP_PRECOMMIT && safe_copy "$PLUGIN_DIR/templates/java/lefthook.yml" "$PROJECT_ROOT/lefthook.yml" "lefthook.yml"
    echo ""
    info "Add dependency: ${BOLD}com.tngtech.archunit:archunit-junit5:1.3.0${NC}"
}

generate_go() {
    safe_copy "$PLUGIN_DIR/templates/go/golangci.yml" "$PROJECT_ROOT/.golangci.yml" ".golangci.yml"
    safe_copy "$PLUGIN_DIR/templates/go/go-arch-lint.yml" "$PROJECT_ROOT/.go-arch-lint.yml" ".go-arch-lint.yml"
    ! $SKIP_PRECOMMIT && safe_copy "$PLUGIN_DIR/templates/go/lefthook.yml" "$PROJECT_ROOT/lefthook.yml" "lefthook.yml"
    echo ""
    info "Install: ${BOLD}go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest${NC}"
}

generate_rust() {
    safe_copy "$PLUGIN_DIR/templates/rust/clippy.toml" "$PROJECT_ROOT/clippy.toml" "clippy.toml"
    safe_copy "$PLUGIN_DIR/templates/rust/rustfmt.toml" "$PROJECT_ROOT/rustfmt.toml" "rustfmt.toml"
    safe_copy "$PLUGIN_DIR/templates/rust/deny.toml" "$PROJECT_ROOT/deny.toml" "deny.toml"
    ! $SKIP_PRECOMMIT && safe_copy "$PLUGIN_DIR/templates/rust/lefthook.yml" "$PROJECT_ROOT/lefthook.yml" "lefthook.yml"
    echo ""
    info "Install: ${BOLD}cargo install cargo-deny${NC}"
}

generate_csharp() {
    safe_copy "$PLUGIN_DIR/templates/csharp/editorconfig" "$PROJECT_ROOT/.editorconfig" ".editorconfig"
    mkdir -p "$PROJECT_ROOT/tests/Architecture"
    safe_copy "$PLUGIN_DIR/templates/csharp/ArchitectureTests.cs" "$PROJECT_ROOT/tests/Architecture/ArchitectureTests.cs" "ArchUnitNET test"
    ! $SKIP_PRECOMMIT && safe_copy "$PLUGIN_DIR/templates/csharp/lefthook.yml" "$PROJECT_ROOT/lefthook.yml" "lefthook.yml"
    echo ""
    info "Install: ${BOLD}dotnet add tests/Architecture package ArchUnitNET.xUnit${NC}"
}

generate_configs() {
    step "Generating configs for $LANGUAGE"
    case "$LANGUAGE" in
        python)     generate_python ;;
        typescript) generate_typescript ;;
        java)       generate_java ;;
        go)         generate_go ;;
        rust)       generate_rust ;;
        csharp)     generate_csharp ;;
        *)          warn "Unknown language: $LANGUAGE" ;;
    esac
}

# ── Generate CI Pipeline ────────────────────────────────────────────────
generate_ci() {
    if $SKIP_CI; then info "Skipping CI (--skip-ci)"; return; fi
    step "Generating CI/CD pipeline"

    local workflow_dir="$PROJECT_ROOT/.github/workflows"
    mkdir -p "$workflow_dir"
    if $DRY_RUN; then info "[DRY RUN] Would create quality-gate.yml"; return; fi

    local template="$PLUGIN_DIR/templates/$LANGUAGE/quality-gate.yml"
    [ ! -f "$template" ] && template="$PLUGIN_DIR/templates/generic-quality-gate.yml"

    if [ -f "$workflow_dir/quality-gate.yml" ]; then
        warn "quality-gate.yml exists — writing quality-gate.guardrails.yml"
        cp "$template" "$workflow_dir/quality-gate.guardrails.yml"
    else
        cp "$template" "$workflow_dir/quality-gate.yml"
    fi
    success "CI pipeline created"
}

# ── Generate CLAUDE.md ──────────────────────────────────────────────────
generate_claude_md() {
    step "Generating CLAUDE.md"
    if $DRY_RUN; then info "[DRY RUN] Would create/update CLAUDE.md"; return; fi

    local claude_md="$PROJECT_ROOT/CLAUDE.md"
    if [ -f "$claude_md" ]; then
        if grep -q "GUARDRAIL ARCHITECT" "$claude_md"; then
            info "CLAUDE.md already has guardrail section"; return
        fi
        echo "" >> "$claude_md"
        cat "$PLUGIN_DIR/templates/CLAUDE-guardrails.md" >> "$claude_md"
        success "Appended guardrail rules to CLAUDE.md"
    else
        cp "$PLUGIN_DIR/templates/CLAUDE-guardrails.md" "$claude_md"
        success "Created CLAUDE.md with architecture rules"
    fi
}

# ── Generate Cursor rules ───────────────────────────────────────────────
generate_cursorrules() {
    if [ -f "$PROJECT_ROOT/.cursorrules" ] || [ -f "$PROJECT_ROOT/.cursor/rules" ]; then
        info "Cursor rules already exist — skipping"
    else
        safe_copy "$PLUGIN_DIR/templates/cursorrules.md" "$PROJECT_ROOT/.cursorrules" ".cursorrules"
    fi
}

# ── Copy branch protection guide ────────────────────────────────────────
copy_branch_protection() {
    mkdir -p "$PROJECT_ROOT/.github"
    safe_copy "$PLUGIN_DIR/templates/branch-protection.md" "$PROJECT_ROOT/.github/branch-protection.md" "branch-protection.md"
}

# ── Summary ──────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║              ✅ GUARDRAIL ARCHITECT INSTALLED                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Installed:${NC}"
    echo -e "  ${CYAN}Commands${NC}     /guardrail:assess :generate :review :fix :arch-check :status"
    ! $SKIP_HOOKS && echo -e "  ${CYAN}Hooks${NC}        lint-on-write, test-on-write, arch-context, final-check"
    echo -e "  ${CYAN}Configs${NC}      Language: $LANGUAGE (see above for details)"
    ! $SKIP_CI && echo -e "  ${CYAN}CI${NC}           .github/workflows/quality-gate.yml"
    echo -e "  ${CYAN}Docs${NC}         CLAUDE.md, .cursorrules, branch-protection.md"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  1. Open Claude Code → type ${CYAN}/guardrail:assess${NC}"
    echo -e "  2. Set up branch protection (see .github/branch-protection.md)"
    echo -e "  3. Test: make a change that violates architecture → watch it catch it"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────
main() {
    detect_language
    detect_existing
    install_commands
    install_hooks
    generate_configs
    generate_ci
    generate_claude_md
    generate_cursorrules
    copy_branch_protection
    print_summary
}

main
