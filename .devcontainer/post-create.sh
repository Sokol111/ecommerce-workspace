#!/usr/bin/env bash
set -euo pipefail

SETTINGS="${HOME}/.claude/settings.json"

# --- Bypass mode: written to the user-level settings INSIDE the container volume only.
# Never committed to the repo, so it cannot activate autonomous mode on the host (where secrets live).
mkdir -p "${HOME}/.claude"
if [ -f "${SETTINGS}" ]; then
  tmp="$(mktemp)"
  jq '.permissions = (.permissions // {}) | .permissions.defaultMode = "bypassPermissions"' \
    "${SETTINGS}" > "${tmp}" && mv "${tmp}" "${SETTINGS}"
else
  echo '{"permissions":{"defaultMode":"bypassPermissions"}}' | jq '.' > "${SETTINGS}"
fi
echo "bypass written to ${SETTINGS}"

# --- Persist global CLI state (~/.claude.json) in the volume too.
# It normally lives on the container fs and is lost on rebuild; symlink it into ~/.claude.
if [ ! -L "${HOME}/.claude.json" ]; then
  if [ -f "${HOME}/.claude.json" ]; then
    mv "${HOME}/.claude.json" "${HOME}/.claude/.claude.json"
  fi
  [ -f "${HOME}/.claude/.claude.json" ] || echo '{}' > "${HOME}/.claude/.claude.json"
  ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json"
  echo "linked ~/.claude.json into volume"
fi

# --- Non-fatal toolchain checks.
echo "--- toolchain ---"
go version || true
node --version || true
pnpm --version || true
golangci-lint version || true
buf --version || true
mockery --version || true
claude --version || true
git --version || true

# --- go.work resolution sanity.
( cd /workspaces/ecommerce && go work edit -json >/dev/null 2>&1 && echo "go.work OK" ) || echo "WARN: go.work check failed"

# --- DinD reachability.
if docker version >/dev/null 2>&1; then
  echo "DinD reachable (isolated from host)"
else
  echo "WARN: docker not reachable yet"
fi
