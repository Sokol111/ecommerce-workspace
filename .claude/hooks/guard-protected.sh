#!/usr/bin/env bash
# PreToolUse hook: block edits to proto-generated files and SOPS secrets.
# Reads the hook payload on stdin; exit 2 blocks the tool call.
set -euo pipefail

f=$(jq -r '.tool_input.file_path // empty')
[ -z "$f" ] && exit 0

case "$f" in
  */gen/go/*|*/gen/typescript/*)
    echo "Blocked: $f is proto-generated. Edit the .proto source and run 'make generate' instead." >&2
    exit 2
    ;;
  *.enc.yaml)
    echo "Blocked: $f is a SOPS-encrypted secret. Use 'make secrets-edit' instead of editing directly." >&2
    exit 2
    ;;
esac
exit 0
