# scripts

## Overview
Shell scripts executed locally on each target RHEL VM by the Azure Pipelines
self-hosted agent. Each script targets one concern — mirror verification, PHP
version install, module install, default switching, upgrade, removal, or
read-only audit. No script installs or enables the public Remi/EPEL
repositories; packages are sourced exclusively from **internal mirrors** that
must already be configured and enabled on the VM.

## Interface
- `mirror-check-lib.sh` — sourced library; functions `detect_rhel_ver()`,
  `get_enabled_baseurls()`, `mirror_in_enabled_repo()`, `run_mirror_check()`,
  `print_mirror_report()`; populates globals `M_RHEL_VER`, `M_REMI_NAME`,
  `M_REMI_URL`, `M_REMI_STATUS`, `M_EPEL_NAME`, `M_EPEL_URL`, `M_EPEL_STATUS`,
  `M_MIRRORS_READY` [mirror-check-lib.sh:run_mirror_check]
- `check-mirrors.sh` — entrypoint; sources `mirror-check-lib.sh`; sets the ADO
  job variable `mirrorsReady` (`true`/`false`) via
  `##vso[task.setvariable]` [check-mirrors.sh:27]
- `install-php.sh` — `$1` = phpVersion (`x.y` | `x.y.z`); `dnf module reset php`
  → `enable php:remi-<x.y>` → `dnf install php` or `php-<x.y.z>`
  [install-php.sh:24,27,31,34]
- `manage-modules.sh` — `$1` = comma-separated modules; reads
  `config/rhel-common/modules.list` + `config/rhel<ver>/modules.list` +
  runtime list; de-duplicates preserving order; `dnf install`
  [manage-modules.sh:read_list,76]
- `switch-php-default.sh` — `$1` = phpVersion; `dnf module enable
  php:remi-<x.y>` → `dnf install php` → `systemctl enable --now` +
  `restart php-fpm` [switch-php-default.sh:24,27,31,32]
- `update-php.sh` — no args; `dnf upgrade 'php*'`; `systemctl restart php-fpm`
  [update-php.sh:13,17]
- `remove-php.sh` — `$1` = `modules` | `all`; `systemctl stop`+`disable
  php-fpm`; `dnf remove` (`all` → `php*` + `dnf module reset php`)
  [remove-php.sh:25,26,32,34,49]
- `audit-php.sh` — `$1` = `table` | `csv`; read-only; sources
  `mirror-check-lib.sh`; reports system, packages, fpm pools, live listeners,
  and mirror status [audit-php.sh:csv_field, run_mirror_check]

## Invariants
- Every executable entrypoint script uses `set -euo pipefail`
  (fail-fast on error/unset); `mirror-check-lib.sh` is a *sourced library*
  and intentionally omits it (the caller inherits the setting)
  [scripts/*.sh: `set -euo pipefail`]
- RHEL major version is auto-detected via `rpm -E '%{rhel}'`; only 9 and 10
  are supported [mirror-check-lib.sh:detect_rhel_ver, run_mirror_check]
- Mirror env vars are per-RHEL: `REMI9_MIRROR`/`EPEL9_MIRROR` (RHEL 9),
  `REMI10_MIRROR`/`EPEL10_MIRROR` (RHEL 10) [mirror-check-lib.sh:run_mirror_check]
- No public Remi/EPEL repository is installed or enabled by any script
  (internal mirrors must pre-exist on the VM)
- `mirrorsReady` must be `true` before install/update/remove action steps run
  (enforced by pipeline step conditions)
- `x.y` installs the latest in stream `php:remi-<x.y>`; `x.y.z` installs the
  exact patch version [install-php.sh]

## Side Effects
- Package state: `dnf install`/`upgrade`/`remove` mutate the installed package
  set [install-php.sh, update-php.sh, remove-php.sh, manage-modules.sh]
- Module stream state: `dnf module reset`/`enable php:remi-<x.y>`
  [install-php.sh, switch-php-default.sh, remove-php.sh]
- Service state: `systemctl enable`/`disable`/`restart`/`stop` `php-fpm`
  [switch-php-default.sh, update-php.sh, remove-php.sh]
- ADO pipeline variable: sets `mirrorsReady` [check-mirrors.sh]
- Reads `/etc/yum.repos.d/*.repo` and `/etc/php*/fpm/pool.d/*.conf`
  [mirror-check-lib.sh:get_enabled_baseurls, audit-php.sh]
- `audit-php.sh` is read-only — no system mutations [audit-php.sh]

## Verification
- Run: `bash ../tests/test-mirrors.sh && bash ../tests/test-php-install.sh <x.y>`