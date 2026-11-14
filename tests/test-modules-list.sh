#!/usr/bin/env bash
# Validate the config/**/modules.list files: every non-blank, non-comment
# line must be a single module package name token (no internal whitespace).
#
# Usage: tests/test-modules-list.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FILES=(
  "${REPO_ROOT}/config/rhel-common/modules.list"
  "${REPO_ROOT}/config/rhel9/modules.list"
  "${REPO_ROOT}/config/rhel10/modules.list"
)

fail=0

for f in "${FILES[@]}"; do
  rel="${f#${REPO_ROOT}/}"
  if [[ ! -f "$f" ]]; then
    echo "FAIL: missing ${rel}" >&2
    fail=1
    continue
  fi
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    stripped="${line%%#*}"            # strip comments (first # onward)
    trimmed="$(echo "$stripped" | xargs)"  # trim whitespace
    [[ -z "$trimmed" ]] && continue
    if [[ "$trimmed" =~ [[:space:]] ]]; then
      echo "FAIL: ${rel}:${lineno}: '${trimmed}' contains whitespace (expected a single module name)" >&2
      fail=1
    fi
  done < "$f"
  echo "  OK  ${rel} ($(grep -cvE '^[[:space:]]*(#|$)' "$f") entries)"
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "PASS: all config modules.list files are well-formed"