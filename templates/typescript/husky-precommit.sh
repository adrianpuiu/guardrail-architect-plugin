#!/usr/bin/env sh
# Guardrail Architect — Husky pre-commit hook
# Install: npx husky init && cp this file .husky/pre-commit
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
npx tsc --noEmit
