#!/usr/bin/env bash
# Read-only audit: report installed PHP version(s), PHP module packages,
# php-fpm listening configuration, and internal mirror status.
# Makes NO changes to the system.
#
# Output formats:
#   table (default)  - aligned ASCII tables/sections
#   csv               - comma-separated values with section markers
#
# Usage: audit-php.sh [table|csv]
set -euo pipefail

FORMAT="${1:-table}"
case "$FORMAT" in
  table|csv) : ;;
  *)
    echo "WARN: unknown format '${FORMAT}', defaulting to table" >&2
    FORMAT="table"
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mirror-check-lib.sh
. "${SCRIPT_DIR}/mirror-check-lib.sh"

HOST="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
RHEL_VER="$(rpm -E '%{rhel}' 2>/dev/null || echo unknown)"

# --- Default PHP ---
PHP_BIN="$(command -v php 2>/dev/null || true)"
if [[ -n "$PHP_BIN" ]]; then
  PHP_VER="$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo unknown)"
else
  PHP_BIN="-"
  PHP_VER="not installed"
fi

# --- Other php binaries on disk ---
shopt -s nullglob
OTHER=()
for b in /usr/bin/php[0-9]* /usr/bin/php-[0-9]* /opt/remi/php[0-9]*/root/usr/bin/php; do
  [[ -x "$b" ]] && OTHER+=("$b")
done
shopt -u nullglob
if [[ "${#OTHER[@]}" -eq 0 ]]; then
  OTHER_TXT="-"
else
  OTHER_TXT="$(IFS=';'; printf '%s' "${OTHER[*]}")"
fi

# --- Installed php packages (NAME|VERSION|ARCH) ---
PKG_ROWS=()
while IFS='|' read -r n v a; do
  [[ -n "${n:-}" ]] || continue
  PKG_ROWS+=("${n}|${v}|${a}")
done < <(rpm -qa --qf '%{NAME}|%{VERSION}|%{ARCH}\n' 2>/dev/null \
  | grep -E '^php(-|[0-9]|$)' | sort || true)

# --- php-fpm pools (from config files) ---
shopt -s nullglob
POOL_FILES=(/etc/php-fpm.d/*.conf
            /etc/php/*/fpm/pool.d/*.conf
            /opt/remi/php*/root/etc/php-fpm.d/*.conf
            /opt/remi/php*/root/etc/php/*/fpm/pool.d/*.conf)
shopt -u nullglob

POOL_ROWS=()
for f in "${POOL_FILES[@]:-}"; do
  [[ -f "$f" ]] || continue
  pool=""
  listen=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    tline="$(echo "$line" | xargs)"
    [[ -z "$tline" ]] && continue
    case "$tline" in \#*) continue ;; esac
    if [[ -z "$pool" && "$tline" =~ ^\[(.+)\]$ ]]; then
      cand="${BASH_REMATCH[1]}"
      [[ "$cand" == "global" ]] && continue
      pool="$cand"
    fi
    if [[ "$tline" =~ ^listen[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      listen="${BASH_REMATCH[1]}"
    fi
  done < "$f"
  [[ -z "$pool" ]] && pool="$(basename "$f" .conf)"
  [[ -z "$listen" ]] && listen="-"
  POOL_ROWS+=("${pool}|${listen}")
done

# --- php-fpm service status ---
FPM_SVC="not installed"
if systemctl list-unit-files 2>/dev/null | grep -qE '^php-fpm\.'; then
  FPM_SVC="$(systemctl is-active php-fpm 2>/dev/null || echo unknown)"
fi

# --- live listeners (ss) ---
LIVE_TCP_RAW="$(ss -lHtnp 2>/dev/null | grep -i 'php-fpm' || true)"
LIVE_SOCK_RAW="$(ss -lHxn 2>/dev/null | grep -i 'php-fpm' || true)"
[[ -z "$LIVE_TCP_RAW" ]] && LIVE_TCP_RAW="(none)"
[[ -z "$LIVE_SOCK_RAW" ]] && LIVE_SOCK_RAW="(none)"

# --- Internal mirrors ---
run_mirror_check || true

# ===== Rendering =====
csv_field() {
  local s="$1"
  if [[ "$s" == *","* || "$s" == *'"'* || "$s" == *$'\n'* ]]; then
    s="\"${s//\"/\"\"}\""
  fi
  printf '%s' "$s"
}

if [[ "$FORMAT" == "csv" ]]; then
  echo "section,system"
  echo "host,rhel_ver,default_php,default_version,other_php"
  printf '%s,%s,%s,%s,%s\n' \
    "$(csv_field "$HOST")" "$(csv_field "$RHEL_VER")" \
    "$(csv_field "$PHP_BIN")" "$(csv_field "$PHP_VER")" \
    "$(csv_field "$OTHER_TXT")"
  echo
  echo "section,packages"
  echo "name,version,arch"
  for r in "${PKG_ROWS[@]:-}"; do
    [[ -z "$r" ]] && continue
    IFS='|' read -r n v a <<< "$r"
    printf '%s,%s,%s\n' "$(csv_field "$n")" "$(csv_field "$v")" "$(csv_field "$a")"
  done
  echo
  echo "section,fpm_pools"
  echo "pool,listen"
  for r in "${POOL_ROWS[@]:-}"; do
    [[ -z "$r" ]] && continue
    IFS='|' read -r p l <<< "$r"
    printf '%s,%s\n' "$(csv_field "$p")" "$(csv_field "$l")"
  done
  echo
  echo "section,fpm_live"
  echo "service,tcp_listeners,unix_listeners"
  LIVE_TCP_CSV="${LIVE_TCP_RAW//$'\n'/; }"
  LIVE_SOCK_CSV="${LIVE_SOCK_RAW//$'\n'/; }"
  printf '%s,%s,%s\n' \
    "$(csv_field "$FPM_SVC")" "$(csv_field "$LIVE_TCP_CSV")" \
    "$(csv_field "$LIVE_SOCK_CSV")"
  echo
  echo "section,mirrors"
  echo "name,status,url"
  printf '%s,%s,%s\n' \
    "$(csv_field "$M_REMI_NAME")" "$(csv_field "$M_REMI_STATUS")" \
    "$(csv_field "$M_REMI_URL")"
  printf '%s,%s,%s\n' \
    "$(csv_field "$M_EPEL_NAME")" "$(csv_field "$M_EPEL_STATUS")" \
    "$(csv_field "$M_EPEL_URL")"
  printf '%s,%s,\n' "mirrors_ready" \
    "$([[ "${M_MIRRORS_READY:-0}" -eq 1 ]] && echo yes || echo no)"
else
  echo "============================================================"
  echo " php_mgmt audit"
  echo "   host=${HOST}   rhel=${RHEL_VER}"
  echo "   default=${PHP_BIN} (${PHP_VER})"
  echo "============================================================"
  echo
  echo "### System & default PHP"
  {
    printf 'host|rhel_ver|default_php|default_version|other_php\n'
    printf '%s|%s|%s|%s|%s\n' "$HOST" "$RHEL_VER" "$PHP_BIN" "$PHP_VER" "$OTHER_TXT"
  } | column -t -s'|'
  echo
  echo "### Installed PHP packages (${#PKG_ROWS[@]})"
  {
    printf 'name|version|arch\n'
    if [[ ${#PKG_ROWS[@]} -gt 0 ]]; then printf '%s\n' "${PKG_ROWS[@]}"; fi
  } | column -t -s'|'
  echo
  echo "### php-fpm pools (${#POOL_ROWS[@]})"
  {
    printf 'pool|listen\n'
    if [[ ${#POOL_ROWS[@]} -gt 0 ]]; then printf '%s\n' "${POOL_ROWS[@]}"; fi
  } | column -t -s'|'
  echo
  echo "### php-fpm service & live listeners"
  echo "    service          : ${FPM_SVC}"
  echo "    tcp listeners    :"
  if [[ "$LIVE_TCP_RAW" != "(none)" ]]; then
    printf '%s\n' "$LIVE_TCP_RAW" | sed 's/^/        /'
  else
    echo "        (none)"
  fi
  echo "    unix listeners   :"
  if [[ "$LIVE_SOCK_RAW" != "(none)" ]]; then
    printf '%s\n' "$LIVE_SOCK_RAW" | sed 's/^/        /'
  else
    echo "        (none)"
  fi
  echo
  echo "### Internal mirrors"
  print_mirror_report
fi