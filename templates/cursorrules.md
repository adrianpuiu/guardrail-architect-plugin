# Cursor Rules — Guardrail Architect

## Architecture Rules
- Follow layered architecture: api -> services -> repositories -> domain
- Domain layer must have ZERO external dependencies — no frameworks, no HTTP, no DB
- No circular dependencies between modules
- No skipping layers (api must not import repositories directly)
- Trading/signals/risk code must not import web framework code

## Code Quality Rules
- All functions must have complete type annotations
- No Any/any types — define proper types or narrow from Unknown
- All datetimes must be timezone-aware (no naive datetimes)
- Max function complexity: 15 (McCabe) | Max function length: 60 lines
- No print()/console.log() in production code — use structured logging
- Use Decimal for monetary values, never float

## Testing Rules
- Every new public function needs a corresponding test
- Tests mirror the src/ structure in tests/
- Test names describe behavior: "should_reject_order_when_risk_limit_exceeded"
- Run related tests after every file change

## Before Committing
Run the full quality suite:
1. Lint + format check
2. Type check (strict mode)
3. Tests (fail fast)
4. Architecture enforcement
5. Security scan

## Principles
- Deterministic enforcement > probabilistic suggestions
- Catch issues during generation, not after PR
- Every guardrail carries forward to the next project
