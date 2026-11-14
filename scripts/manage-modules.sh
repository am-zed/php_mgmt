#!/usr/bin/env bash
# Install a set of PHP modules from the Remi repository.
#
# The installed module set is the merge (de-duplicated, order-preserving) of:
#   1. config/rhel-common/modules.list      (shared defaults)
#   2. config/rhel<ver>/modules.list         (OS-specific overrides/additions)
#   3. the comma-separated list passed as $1 (runtime overrides from pipeline)
#
# Usage:
#   manage-modules.sh [modules]   # modules = comma-separated string (may be empty)
set -euo pipefail

MODULES_INPUT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RHEL_VER="$(rpm -E '%{rhel}' 2>/dev/null || true)"

if [[ -z "${RHEL_VER}" ]]; then
  echo "ERROR: cannot determine RHEL major version." >&2
  exit 1
fi

COMMON_FILE="${REPO_ROOT}/config/rhel-common/modules.list"
OS_FILE="${REPO_ROOT}/config/rhel${RHEL_VER}/modules.list"

MODULES=()

read_list() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"        # strip full-line comments
    line="$(echo "${line}" | xargs)"  # trim whitespace
    [[ -z "${line}" ]] && continue
    MODULES+=("${line}")
  done < "${file}"
}

echo "==> Building module list"
echo "    common defaults : ${COMMON_FILE}"
echo "    OS-specific      : ${OS_FILE}"
[[ -n "${MODULES_INPUT}" ]] && echo "    runtime supplied : ${MODULES_INPUT}"

read_list "${COMMON_FILE}"
read_list "${OS_FILE}"

# Runtime modules from the pipeline parameter.
if [[ -n "${MODULES_INPUT}" ]]; then
  IFS=',' read -ra INPUT_ARR <<< "${MODULES_INPUT}"
  for m in "${INPUT_ARR[@]}"; do
    m="$(echo "${m}" | xargs)"
    [[ -z "${m}" ]] && continue
    MODULES+=("${m}")
  done
fi

# De-duplicate while preserving order.
declare -A SEEN=()
FINAL=()
for m in "${MODULES[@]:-}"; do
  [[ -z "${m}" ]] && continue
  if [[ -z "${SEEN[${m}]+x}" ]]; then
    SEEN["${m}"]=1
    FINAL+=("${m}")
  fi
done

if [[ "${#FINAL[@]}" -eq 0 ]]; then
  echo "==> No modules to install."
  exit 0
fi

echo "==> Installing ${#FINAL[@]} PHP module(s):"
printf '    - %s\n' "${FINAL[@]}"

dnf install -y "${FINAL[@]}"

echo "==> Installed PHP extension packages:"
rpm -qa | grep -E '^php[0-9]*-' || true