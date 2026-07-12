#!/usr/bin/env bash
# PostToolUse hook: fix the edited TS/Vue/JS file with the owning repo's eslint.
# Multi-repo: eslint must run from the repo root (nearest eslint.config.mjs) so it
# picks up that repo's flat config and locally-installed eslint. Reads payload on stdin.
set -euo pipefail

f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -z "$f" ] && exit 0
case "$f" in
  *.ts|*.tsx|*.vue|*.js|*.mjs) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0

# Walk up to the nearest eslint.config.mjs — that directory is the repo root.
dir=$(dirname "$f")
while [ "$dir" != "/" ] && [ ! -f "$dir/eslint.config.mjs" ]; do
  dir=$(dirname "$dir")
done
[ -f "$dir/eslint.config.mjs" ] || exit 0                 # not a linted UI repo
[ -x "$dir/node_modules/.bin/eslint" ] || exit 0          # deps not installed — skip

( cd "$dir" && ./node_modules/.bin/eslint --fix "$f" )
exit 0
