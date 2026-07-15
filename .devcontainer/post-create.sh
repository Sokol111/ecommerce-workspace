#!/usr/bin/env bash
set -euo pipefail

# --- Non-fatal toolchain checks.
echo "--- toolchain ---"
go version || true
node --version || true
pnpm --version || true
golangci-lint version || true
buf --version || true
mockery version || true
opencode --version || true
git --version || true

# --- go.work resolution sanity.
( cd /workspaces/ecommerce && go work edit -json >/dev/null 2>&1 && echo "go.work OK" ) || echo "WARN: go.work check failed"

# --- DinD reachability.
if docker version >/dev/null 2>&1; then
  echo "DinD reachable (isolated from host)"
else
  echo "WARN: docker not reachable yet"
fi
