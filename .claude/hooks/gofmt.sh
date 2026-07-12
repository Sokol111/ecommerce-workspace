#!/usr/bin/env bash
# PostToolUse hook: format the edited Go file with gofmt -s and goimports.
# Reads the hook payload on stdin; only acts on *.go files.
set -euo pipefail

f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')
[ -z "$f" ] && exit 0
case "$f" in
  *.go) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0

gofmt -s -w "$f"
command -v goimports >/dev/null 2>&1 && goimports -w "$f"
exit 0
