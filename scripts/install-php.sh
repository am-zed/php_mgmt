#!/usr/bin/env bash
# Install a target PHP version from the Remi repository.
#
# Usage:
#   install-php.sh <x.y | x.y.z>
#
#   <x.y>     -> enable the remi-<x.y> module stream and install latest in stream
#   <x.y.z>   -> enable the remi-<x.y> stream and install the exact patch version
set -euo pipefail

PHP_VERSION="${1:-}"
if [[ -z "${PHP_VERSION}" ]]; then
  echo "ERROR: PHP version is required." >&2
  echo "Usage: $0 <x.y | x.y.z>" >&2
  exit 1
fi

MAJOR_MINOR="$(echo "${PHP_VERSION}" | awk -F. '{print $1"."$2}')"
COMPONENTS="$(echo "${PHP_VERSION}" | awk -F. '{print NF}')"

echo "==> Target PHP: ${PHP_VERSION} (stream php:remi-${MAJOR_MINOR})"

echo "==> Resetting the php module to allow stream selection"
dnf module reset -y php || true

echo "==> Enabling Remi php module stream php:remi-${MAJOR_MINOR}"
dnf module enable -y "php:remi-${MAJOR_MINOR}"

if [[ "${COMPONENTS}" == "3" ]]; then
  echo "==> Installing exact package version php-${PHP_VERSION}"
  dnf install -y "php-${PHP_VERSION}"
else
  echo "==> Installing php (latest available in the remi-${MAJOR_MINOR} stream)"
  dnf install -y php
fi

echo "==> Installed PHP:"
php -v