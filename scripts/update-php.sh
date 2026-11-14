#!/usr/bin/env bash
# Upgrade all installed PHP packages to the latest available in the currently
# enabled Remi stream, then restart php-fpm so the new binaries are loaded.
#
# No version argument: upgrades whatever stream is currently enabled/installed.
# Usage: update-php.sh
set -euo pipefail

echo "==> Refreshing repository metadata"
dnf clean expire-cache || true

echo "==> Upgrading all installed php* packages"
dnf upgrade -y 'php*'

echo "==> Restarting php-fpm (if present) to load upgraded binaries"
if systemctl list-unit-files 2>/dev/null | grep -qE '^php-fpm\.'; then
  systemctl restart php-fpm || true
  systemctl --no-pager status php-fpm --full || true
else
  echo "    php-fpm unit not found; skipping service restart"
fi

if command -v php &>/dev/null; then
  echo "==> PHP after upgrade:"
  php -v
else
  echo "==> No php executable on PATH after upgrade"
fi