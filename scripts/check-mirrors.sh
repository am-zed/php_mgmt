#!/usr/bin/env bash
# Verify the internal Remi and EPEL mirrors for this RHEL version are
# configured and enabled on the target VM. Read-only; makes no changes.
#
# Sets the Azure Pipelines job variable `mirrorsReady` (true/false) so that
# subsequent install/update/remove steps can skip the host when the
# prerequisite mirrors are missing.
#
# Expected environment variables (agent-level; per RHEL version):
#   RHEL 9  -> REMI9_MIRROR,  EPEL9_MIRROR
#   RHEL 10 -> REMI10_MIRROR, EPEL10_MIRROR
#
# Each value is a baseurl (or a unique substring of one) that must appear in
# an ENABLED repo in /etc/yum.repos.d/*.repo. If a mirror is unset or not
# enabled on the VM, a warning is emitted and the host is skipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mirror-check-lib.sh
. "${SCRIPT_DIR}/mirror-check-lib.sh"

echo "==> Checking internal mirror configuration"
run_mirror_check || true
print_mirror_report

if [[ "${M_MIRRORS_READY:-0}" -eq 1 ]]; then
  echo "##vso[task.setvariable variable=mirrorsReady]true"
  echo "==> Mirrors ready: proceeding with PHP management"
else
  echo "##vso[task.setvariable variable=mirrorsReady]false"
  echo "==> WARN: required internal mirrors not configured/enabled on this host; skipping"
fi