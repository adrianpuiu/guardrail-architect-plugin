# Branch Protection Setup — Guardrail Architect

Configure in GitHub → Settings → Branches → Branch protection rules.

## Rule: `main`

- [x] Require a pull request before merging
  - [x] Require approvals: 1
  - [x] Dismiss stale PR approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - Required checks:
    - `lint-and-format` (or `lint-and-types`)
    - `type-check`
    - `test`
    - `architecture`
    - `security`
    - `pr-size-check`
- [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings
- [ ] Restrict who can push (optional — add team leads)

## Why This Matters for Agentic Coding

AI agents create PRs fast. Without branch protection:
- Agents can merge their own PRs immediately
- Quality gate failures go unnoticed
- Architecture violations accumulate silently
- A single bad merge can undo weeks of clean architecture

Branch protection is the **backstop** that makes CI gates meaningful.
Without it, quality gates are suggestions. With it, they're walls.
