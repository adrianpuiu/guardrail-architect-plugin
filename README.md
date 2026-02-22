# 🛡️ Guardrail Architect — Claude Code Plugin

> Production-grade guardrails for agentic coding. One install. All four layers.

## Quick Start (30 seconds)

```bash
git clone https://github.com/your-org/guardrail-architect-plugin.git
cd your-project
../guardrail-architect-plugin/install.sh
```

With options:
```bash
./install.sh --language python              # Force language
./install.sh --skip-hooks --skip-precommit  # Minimal install
./install.sh --dry-run                      # Preview without changes
```

## What Gets Installed

### 6 Slash Commands

| Command | What It Does |
|---------|-------------|
| `/guardrail:assess` | Score your project across all 4 layers (0-3 each) |
| `/guardrail:generate` | Generate production configs for weak/missing layers |
| `/guardrail:review` | Adversarial review — separate critic finds problems |
| `/guardrail:fix` | Auto-fix lint + format issues |
| `/guardrail:arch-check` | Run architecture dependency tests |
| `/guardrail:status` | One-glance health dashboard |

### 4 Session Hooks

| Event | Hook | Effect |
|-------|------|--------|
| `sessionStart` | `load-architecture-context.sh` | Injects arch rules into agent context |
| `preToolUse(write_file)` | `lint-on-write.sh` | Lints every file before write accepted |
| `postToolUse(write_file)` | `test-on-write.sh` | Runs related tests after file change |
| `sessionEnd` | `final-quality-check.sh` | Full sweep: lint + types + tests + arch |

### Language-Specific Configs

| Language | Linter | Type Checker | Arch Tests | Pre-commit | CI Pipeline |
|----------|--------|-------------|------------|------------|-------------|
| Python | Ruff | mypy strict | import-linter | pre-commit | ✅ |
| TypeScript | ESLint 9 | tsc strict | dependency-cruiser | husky + lint-staged | ✅ |
| Java | Checkstyle | javac | ArchUnit | lefthook | ✅ |
| Go | golangci-lint | go compiler | go-arch-lint | lefthook | ✅ |
| Rust | clippy | rustc | cargo-deny | lefthook | ✅ |
| C# | .NET Analyzers | csc + nullable | ArchUnitNET | lefthook | ✅ |

### Additional Files
- **CLAUDE.md** — Architecture rules loaded at every session start
- **.cursorrules** — Same rules for Cursor users
- **branch-protection.md** — Manual setup guide for GitHub
- **adversarial-review.py** — Standalone critic script using Anthropic API

## Example Session

```
> /guardrail:assess

## Guardrail Assessment: trading-engine

Stack: Python 3.12, FastAPI, pytest, uv
CI: GitHub Actions (build only — no quality gates)

| Layer                     | Score | Status                       |
|---------------------------|-------|------------------------------|
| CI/CD Pipeline            | 1/3   | Build only, no quality gates |
| Code Quality              | 1/3   | Ruff present, no mypy        |
| Architectural Enforcement | 0/3   | No dependency rules           |
| Agentic Hooks             | 1/3   | Basic CLAUDE.md only          |
| **Total**                 | 3/12  |                              |

Which recommendations should I implement?

> All of them.

[Generates: CI pipeline, ruff.toml, mypy strict, import-linter contracts,
 Claude hooks, pre-commit config, .cursorrules]
```

## File Structure

```
guardrail-architect-plugin/
├── install.sh                              # One-command installer (auto-detects language)
├── README.md
│
├── .claude/commands/                       # Slash commands for Claude Code
│   ├── assess.md                           # /guardrail:assess
│   ├── generate.md                         # /guardrail:generate
│   ├── review.md                           # /guardrail:review
│   ├── fix.md                              # /guardrail:fix
│   ├── arch-check.md                       # /guardrail:arch-check
│   └── status.md                           # /guardrail:status
│
├── scripts/guardrails/                     # Hook scripts
│   ├── lint-on-write.sh                    # preToolUse hook (all languages)
│   ├── test-on-write.sh                    # postToolUse hook (all languages)
│   ├── load-architecture-context.sh        # sessionStart hook
│   ├── final-quality-check.sh              # sessionEnd hook
│   └── adversarial-review.py               # Standalone critic (requires ANTHROPIC_API_KEY)
│
└── templates/                              # Language-specific configs
    ├── CLAUDE-guardrails.md                # CLAUDE.md template
    ├── cursorrules.md                      # .cursorrules template
    ├── branch-protection.md                # GitHub setup guide
    ├── generic-quality-gate.yml            # Fallback CI pipeline
    │
    ├── python/
    │   ├── ruff.toml                       # Linting (ANN, DTZ, S, C90, ICN)
    │   ├── mypy-section.toml               # Strict type checking (append to pyproject.toml)
    │   ├── importlinter-section.toml       # Architecture contracts (append to pyproject.toml)
    │   ├── pre-commit-config.yaml          # Pre-commit hooks
    │   └── quality-gate.yml                # GitHub Actions CI pipeline
    │
    ├── typescript/
    │   ├── eslint.config.mjs               # ESLint 9 strict type-checked
    │   ├── tsconfig.strict.json            # TypeScript strict overlay
    │   ├── dependency-cruiser.cjs          # Architecture dependency rules
    │   ├── husky-precommit.sh              # Husky pre-commit hook
    │   ├── lint-staged.json                # lint-staged config
    │   └── quality-gate.yml                # GitHub Actions CI pipeline
    │
    ├── java/
    │   ├── checkstyle.xml                  # Checkstyle config (Google + guardrails)
    │   ├── ArchitectureTest.java           # ArchUnit test class
    │   ├── lefthook.yml                    # Pre-commit hooks
    │   └── quality-gate.yml                # GitHub Actions CI pipeline
    │
    ├── go/
    │   ├── golangci.yml                    # golangci-lint config (exhaustive)
    │   ├── go-arch-lint.yml                # Architecture layer definitions
    │   ├── lefthook.yml                    # Pre-commit hooks
    │   └── quality-gate.yml                # GitHub Actions CI pipeline
    │
    ├── rust/
    │   ├── clippy.toml                     # Clippy pedantic config
    │   ├── rustfmt.toml                    # Formatting config
    │   ├── deny.toml                       # Dependency audit + license check
    │   ├── lefthook.yml                    # Pre-commit hooks
    │   └── quality-gate.yml                # GitHub Actions CI pipeline
    │
    └── csharp/
        ├── editorconfig                    # .NET code style + nullable errors
        ├── ArchitectureTests.cs            # ArchUnitNET test class
        ├── lefthook.yml                    # Pre-commit hooks
        └── quality-gate.yml               # GitHub Actions CI pipeline
```

## The Four Layers

```
Layer 4: Agentic Hooks ────── During generation (hooks, sessions, CLAUDE.md)
Layer 3: Architecture ─────── Dependency rules as executable tests
Layer 2: Code Quality ─────── Linting + strict types + security scanning
Layer 1: CI/CD Pipeline ───── Final gate before merge
```

Each layer catches what the layer above misses. Defense in depth.

## Philosophy

1. **Deterministic > Probabilistic** — Tools that enforce > prompts that suggest
2. **Shift Left** — Catch during generation (hooks), not after PR (CI)
3. **Hooks Beat Prompts** — Agents forget rules over long sessions. Hooks don't.
4. **Compound Returns** — Every guardrail carries to the next project
5. **Extend, Never Replace** — Installer only adds what's missing

## License

MIT
