#!/usr/bin/env bash
# Remove specified PHP modules, or the entire PHP stack.
#
# Usage:
#   remove-php.sh [modules]
#
#   modules = comma-separated module package names to remove.
#             Special values:
#               all  -> remove the entire PHP stack (all php* packages) and
#                       reset the php module stream.
#
# No repository access is required for removal.
set -euo pipefail

MODULES_INPUT="${1:-}"

if [[ -z "${MODULES_INPUT}" ]]; then
  echo "ERROR: no modules specified. Pass a comma-separated list or 'all'." >&2
  echo "Usage: $0 <modules|all>" >&2
  exit 2
fi

echo "==> Stopping php-fpm before removal (if present)"
if systemctl list-unit-files 2>/dev/null | grep -qE '^php-fpm\.'; then
  systemctl stop php-fpm || true
  systemctl disable php-fpm || true
fi

case "${MODULES_INPUT}" in
  all|ALL|\*)
    echo "==> Removing entire PHP stack (all php* packages)"
    dnf remove -y 'php*'
    echo "==> Resetting the php module stream"
    dnf module reset -y php || true
    ;;
  *)
    IFS=',' read -ra ARR <<< "${MODULES_INPUT}"
    PKGS=()
    for m in "${ARR[@]}"; do
      m="$(echo "${m}" | xargs)"
      [[ -z "${m}" ]] && continue
      PKGS+=("${m}")
    done
    if [[ "${#PKGS[@]}" -eq 0 ]]; then
      echo "ERROR: no valid module names parsed from input '${MODULES_INPUT}'." >&2
      exit 2
    fi
    echo "==> Removing ${#PKGS[@]} package(s): ${PKGS[*]}"
    dnf remove -y "${PKGS[@]}"
    ;;
esac

echo "==> Removal complete"
if command -v php &>/dev/null; then
  echo "==> Remaining default PHP:"
  php -v
else
  echo "==> No php executable on PATH after removal"
fi