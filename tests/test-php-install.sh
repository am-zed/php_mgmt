#!/usr/bin/env bash
# Verify the installed PHP matches the requested version (major.minor).
#
# Usage:
#   test-php-install.sh <x.y | x.y.z>
set -euo pipefail

PHP_VERSION="${1:-}"
if [[ -z "${PHP_VERSION}" ]]; then
  echo "ERROR: expected PHP version argument" >&2
  echo "Usage: $0 <x.y | x.y.z>" >&2
  exit 1
fi

EXPECTED_MM="$(echo "${PHP_VERSION}" | awk -F. '{print $1"."$2}')"

if ! command -v php &>/dev/null; then
  echo "FAIL: php executable not found on PATH" >&2
  exit 1
fi

ACTUAL_MM="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"

if [[ "${ACTUAL_MM}" != "${EXPECTED_MM}" ]]; then
  echo "FAIL: expected PHP ${EXPECTED_MM}, got ${ACTUAL_MM}" >&2
  php -v >&2
  exit 1
fi

echo "PASS: PHP ${ACTUAL_MM} is installed and matches requested ${EXPECTED_MM}"

if [[ "$(echo "${PHP_VERSION}" | awk -F. '{print NF}')" -eq 3 ]]; then
  ACTUAL_FULL="$(php -r 'echo PHP_VERSION;')"
  echo "    runtime reports PHP_VERSION=${ACTUAL_FULL}"
fi