#!/usr/bin/env bash
# Standalone test: verify internal Remi & EPEL mirrors are configured and
# enabled on this VM. Passes only when all required mirrors are "OK (enabled)".
#
# Usage: tests/test-mirrors.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/mirror-check-lib.sh
. "${SCRIPT_DIR}/../scripts/mirror-check-lib.sh"

echo "==> Verifying internal mirror configuration"
if run_mirror_check; then
  print_mirror_report
  echo "PASS: all required internal mirrors enabled"
else
  print_mirror_report
  echo "FAIL: one or more required internal mirrors missing" >&2
  exit 1
fi