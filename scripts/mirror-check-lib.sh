# mirror-check-lib.sh - shared internal-mirror verification.
# Sourced (not executed) by check-mirrors.sh, audit-php.sh, tests/test-mirrors.sh.
# Defines functions; the caller invokes run_mirror_check.

# Detect the running RHEL major version (echoes "9", "10", or empty).
detect_rhel_ver() {
  rpm -E '%{rhel}' 2>/dev/null || true
}

# Print every baseurl from ENABLED repos in /etc/yum.repos.d/*.repo.
# A repo is "enabled" when enabled=1, or enabled is absent (dnf default).
# A repo may have multiple baseurl= lines; all are emitted, newline-separated.
get_enabled_baseurls() {
  awk '
    function reset() { enabled = 1; url = ""; }
    BEGIN { reset() }
    /^\[/ {
      if (enabled && url != "") print url;
      reset(); next
    }
    /^[[:space:]]*enabled[[:space:]]*=/ {
      v = $0
      sub(/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*/, "", v)
      sub(/[[:space:]]*#.*$/, "", v)
      sub(/[[:space:]]+$/, "", v)
      enabled = (v == "1" || tolower(v) == "true")
      next
    }
    /^[[:space:]]*baseurl[[:space:]]*=/ {
      v = $0
      sub(/^[[:space:]]*baseurl[[:space:]]*=[[:space:]]*/, "", v)
      if (url == "") url = v; else url = url "\n" v;
      next
    }
    END { if (enabled && url != "") print url; }
  ' /etc/yum.repos.d/*.repo 2>/dev/null || true
}

# Return 0 if $1 appears (as a fixed, case-insensitive substring) in any
# enabled baseurl; 1 otherwise.
mirror_in_enabled_repo() {
  local needle="$1"
  [[ -z "$needle" ]] && return 1
  get_enabled_baseurls | grep -F -i -q -- "$needle"
}

# Populate mirror globals for the detected RHEL version.
# Sets:  M_RHEL_VER, M_REMI_NAME, M_REMI_URL, M_REMI_STATUS,
#        M_EPEL_NAME, M_EPEL_URL, M_EPEL_STATUS, M_MIRRORS_READY
# Returns 0 only when both required mirrors are "OK (enabled)".
#
# Per RHEL version the expected environment variables are:
#   RHEL 9  -> REMI9_MIRROR,  EPEL9_MIRROR
#   RHEL 10 -> REMI10_MIRROR, EPEL10_MIRROR
run_mirror_check() {
  M_RHEL_VER="$(detect_rhel_ver)"
  M_MIRRORS_READY=0

  case "$M_RHEL_VER" in
    9|10) : ;;
    *)
      M_REMI_NAME="REMI${M_RHEL_VER:-?}_MIRROR"
      M_REMI_URL="";  M_REMI_STATUS="UNSUPPORTED RHEL"
      M_EPEL_NAME="EPEL${M_RHEL_VER:-?}_MIRROR"
      M_EPEL_URL="";  M_EPEL_STATUS="UNSUPPORTED RHEL"
      return 1
      ;;
  esac

  M_REMI_NAME="REMI${M_RHEL_VER}_MIRROR"
  M_EPEL_NAME="EPEL${M_RHEL_VER}_MIRROR"
  M_REMI_URL="${!M_REMI_NAME:-}"
  M_EPEL_URL="${!M_EPEL_NAME:-}"

  if [[ -z "$M_REMI_URL" ]]; then
    M_REMI_STATUS="NOT CONFIGURED"
  elif mirror_in_enabled_repo "$M_REMI_URL"; then
    M_REMI_STATUS="OK (enabled)"
  else
    M_REMI_STATUS="NOT ENABLED"
  fi

  if [[ -z "$M_EPEL_URL" ]]; then
    M_EPEL_STATUS="NOT CONFIGURED"
  elif mirror_in_enabled_repo "$M_EPEL_URL"; then
    M_EPEL_STATUS="OK (enabled)"
  else
    M_EPEL_STATUS="NOT ENABLED"
  fi

  if [[ "$M_REMI_STATUS" == "OK (enabled)" && "$M_EPEL_STATUS" == "OK (enabled)" ]]; then
    M_MIRRORS_READY=1
    return 0
  fi
  return 1
}

# Human-readable mirror report from the M_* globals set by run_mirror_check.
print_mirror_report() {
  echo "  RHEL              : ${M_RHEL_VER:-unknown}"
  echo "  ${M_REMI_NAME:-REMI_MIRROR} : ${M_REMI_STATUS:-?}${M_REMI_URL:+  ${M_REMI_URL}}"
  echo "  ${M_EPEL_NAME:-EPEL_MIRROR} : ${M_EPEL_STATUS:-?}${M_EPEL_URL:+  ${M_EPEL_URL}}"
  if [[ "${M_MIRRORS_READY:-0}" -eq 1 ]]; then
    echo "  -> all required mirrors enabled"
  else
    echo "  -> one or more required mirrors missing; host will be skipped"
  fi
}