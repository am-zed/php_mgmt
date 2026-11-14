#!/usr/bin/env bash
# Make the target PHP version the active/default PHP on the system and restart
# php-fpm so the new default takes effect.
#
# Usage:
#   switch-php-default.sh <x.y | x.y.z>
#
# On RHEL with Remi modules, "default" = the enabled php module stream, which
# provides /usr/bin/php. This script ensures that stream is enabled, the php
# meta-package is (re)installed to align /usr/bin/php, and php-fpm is running.
set -euo pipefail

PHP_VERSION="${1:-}"
if [[ -z "${PHP_VERSION}" ]]; then
  echo "ERROR: PHP version is required." >&2
  echo "Usage: $0 <x.y | x.y.z>" >&2
  exit 1
fi

MAJOR_MINOR="$(echo "${PHP_VERSION}" | awk -F. '{print $1"."$2}')"

echo "==> Enabling php:remi-${MAJOR_MINOR} as the default stream"
dnf module reset -y php || true
dnf module enable -y "php:remi-${MAJOR_MINOR}"

echo "==> Aligning /usr/bin/php with the enabled stream"
dnf install -y php

echo "==> Ensuring php-fpm is enabled and (re)started"
if systemctl list-unit-files | grep -q '^php-fpm'; then
  systemctl enable --now php-fpm
  systemctl restart php-fpm
  systemctl --no-pager status php-fpm --full || true
else
  echo "    php-fpm unit not found; skipping service management"
fi

echo "==> Default PHP is now:"
php -v
php -r 'echo "PHP_VERSION=" . PHP_VERSION . PHP_EOL;'