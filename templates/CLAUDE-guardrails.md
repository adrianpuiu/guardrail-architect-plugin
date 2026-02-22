# CLAUDE.md — GUARDRAIL ARCHITECT

> This file is loaded at the start of every Claude Code session.
> Rules marked **ENFORCED** are backed by automated tools — violations fail CI.
> Rules marked **CONVENTION** are best practices — follow unless you have a good reason not to.

## Architecture

<!-- ENFORCED by import-linter / dependency-cruiser / ArchUnit -->

This project uses **layered architecture** with strict dependency rules:

```
  api/controllers  →  services  →  repositories  →  domain
```

Dependencies flow **downward only**. Never skip layers.

### Layer Rules (ENFORCED)

| Layer | Can Import From | Cannot Import From |
|-------|----------------|-------------------|
| `api/` `controllers/` | services, domain | repositories, infrastructure, database |
| `services/` | repositories, domain | api, controllers, infrastructure |
| `repositories/` | domain | api, services, controllers |
| `domain/` | **NOTHING** | everything else — domain is pure |

### Additional Constraints (ENFORCED)
- **No circular dependencies** between any modules
- **Domain layer has zero external dependencies** — no frameworks, no HTTP, no DB clients
- **Trading engine isolation** (if applicable) — signals, risk, model code never imports web framework

## Code Quality

<!-- ENFORCED by linter + type checker in CI -->

### Type Safety (ENFORCED)
- All functions must have complete type annotations
- No `Any` / `any` types — use proper types and narrow from `Unknown` if needed
- All datetimes must be timezone-aware (no naive datetimes)
- Use branded/NewType for domain identifiers (UserId, OrderId — not plain str/string)

### Style (ENFORCED)
- Max function complexity: 15 (McCabe/cyclomatic)
- Max function length: 60 lines — decompose if longer
- No `print()` / `console.log()` in production code — use structured logging
- Imports must be sorted and grouped

### Naming (CONVENTION)
- Services: `*Service` (TradingService, RiskService)
- Repositories: `*Repository` (OrderRepository)
- Domain models: plain nouns (Order, Position, Signal)
- Test classes: `Test*` or `*Test`

## Testing

### Requirements (ENFORCED in CI)
- Every new public function needs a test
- Tests mirror `src/` structure in `tests/`
- Coverage must not drop below 70%
- Test names must describe behavior, not implementation

### Categories (CONVENTION)
- **Unit**: fast, no I/O, no external deps
- **Integration**: marked with appropriate decorator/tag
- **Backtest** (if applicable): marked `@backtest` or equivalent

## Guardrail Commands

| Command | What It Does |
|---------|-------------|
| `/guardrail:assess` | Score project across all 4 guardrail layers |
| `/guardrail:generate` | Generate missing configs |
| `/guardrail:review` | Adversarial review of current changes |
| `/guardrail:fix` | Auto-fix lint and format issues |
| `/guardrail:arch-check` | Run architecture tests |
| `/guardrail:status` | Quick health check dashboard |

## Principles

1. **Deterministic > Probabilistic** — A linter that blocks beats a prompt that suggests
2. **Shift Left** — Catch during generation (hooks), not after PR (CI)
3. **Hooks Beat Prompts** — You will forget rules over long sessions. Hooks won't.
4. **Compound Returns** — Every guardrail carries forward to every future project
