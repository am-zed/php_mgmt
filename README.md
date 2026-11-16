# php_mgmt Blueprint

## System Overview

Manually-triggered Azure Pipelines workflow that installs, updates, removes, or
audits a **PHP** version and set of **PHP modules** on self-hosted DevOps
agents running **RHEL 9** and **RHEL 10**, and optionally sets the installed
version as the system default.

Packages are sourced **exclusively from internal mirrors** that must already be
configured and enabled on each target VM. The public Remi/EPEL repositories are
**never** installed, enabled, or contacted by this pipeline.

### Modes (`mode` parameter)

| Mode      | Action                                                              |
|-----------|---------------------------------------------------------------------|
| `install` | Install a PHP version + modules (default); optionally set default. |
| `update`  | Upgrade all installed `php*` packages to latest in the stream.      |
| `remove`  | Remove specified modules (`modules`) or the whole stack (`all`).    |
| `audit`   | Read-only: report installed PHP, modules, fpm config, and mirrors.   |

### Pipeline parameters (manual run)

| Parameter      | Type    | Default     | Description                                                  |
|----------------|---------|-------------|--------------------------------------------------------------|
| `mode`         | string  | `install`   | `install` \| `update` \| `remove` \| `audit`.                |
| `phpVersion`   | string  | `8.3`       | Target PHP (`x.y` latest-in-stream, or exact `x.y.z`).       |
| `modules`      | string  | _empty_     | Comma-separated modules: added (install), removed (remove), `all` removes whole stack. |
| `targetVMs`    | string  | _empty_     | Comma-separated VM names to run on (one job each; required). |
| `poolName`     | string  | `rhel-pool` | Self-hosted agent pool.                                       |
| `setAsDefault` | boolean | `false`     | (install) enable stream + restart `php-fpm`.                  |
| `outputFormat` | string  | `table`     | (audit) `table` \| `csv`.                                     |

> Trigger is **manual only** (`trigger: none`). Each VM in `targetVMs` expands
> into a job pinned to that agent via an `Agent.Name` demand.

## Local Interface & Invariants
- `azure-pipelines.yml` — main pipeline; `trigger: none` (manual); parameters
  `mode`, `phpVersion`, `modules`, `targetVMs`, `poolName`, `setAsDefault`,
  `outputFormat`; `stages` → `jobs` → `template: pipelines/templates/php-mgmt-job.yml`
  [azure-pipelines.yml:13,57]
- No source files at the root other than the pipeline definition above.

## Subdirectories & System Boundaries
- [pipelines](./pipelines/README.md) - Azure Pipelines templates (job + steps)
- [scripts](./scripts/README.md) - shell scripts run locally on each target VM
- [config](./config/README.md) - declarative module lists partitioned by RHEL version

## Global Invariants
- Manual trigger only (`trigger: none`) [azure-pipelines.yml:13]
- Packages sourced exclusively from internal mirrors (no public Remi/EPEL is
  installed or enabled) [scripts/mirror-check-lib.sh]
- Mirror baseurls are defined as pipeline variables in `azure-pipelines.yml`
  and passed into the mirror-check/audit Bash tasks via their `env:` block;
  `mirror-check-lib.sh` reads them as `REMI9_MIRROR`/`EPEL9_MIRROR` (RHEL 9) or
  `REMI10_MIRROR`/`EPEL10_MIRROR` (RHEL 10) based on the detected RHEL major
  version. The matching repo must still already be configured and ENABLED in
  `/etc/yum.repos.d/*.repo` on each target VM [scripts/mirror-check-lib.sh]
- RHEL version is auto-detected via `rpm -E '%{rhel}'`; only 9 and 10 are
  supported [scripts/mirror-check-lib.sh:detect_rhel_ver]
- Action steps (install/update/remove/switch/verify) are gated on
  `mirrorsReady == 'true'`; the `audit` step always runs (read-only)
  [pipelines/templates/php-mgmt-job.yml]
- Module list = merge(`rhel-common`, `rhel<ver>`, runtime `modules`),
  de-duplicated, order-preserving [scripts/manage-modules.sh]
- `x.y` installs the latest in stream `php:remi-<x.y>`; `x.y.z` installs the
  exact patch version [scripts/install-php.sh]
- `remove` with `modules=all` removes the entire `php*` stack and resets the
  `php` module stream [scripts/remove-php.sh]

### Internal mirror status values

| Status             | Meaning                                                    |
|--------------------|------------------------------------------------------------|
| `OK (enabled)`     | Env var set AND found in an enabled repo's `baseurl`.       |
| `NOT CONFIGURED`   | Env var unset/empty on the agent.                          |
| `NOT ENABLED`      | Env var set but not present in any enabled repo `baseurl`. |
| `UNSUPPORTED RHEL` | RHEL major version is not 9 or 10.                         |

## Global Side Effects
- On each target VM: `dnf` package state, `php` module stream state, and
  `php-fpm` service state (enable/disable/restart/stop) [scripts/]
- ADO job variable `mirrorsReady` set by the mirror-check step
  [scripts/check-mirrors.sh]
- `audit` mode is read-only and mutates nothing [scripts/audit-php.sh]

### Audit output (`audit` mode / after `update` & `remove`)

Read-only report with sections: System & default PHP, Installed PHP packages,
php-fpm pools, php-fpm service & live listeners, and Internal mirrors. Use
`outputFormat=csv` for machine consumption (default `table`).

## System Verification
- Run: `bash tests/test-mirrors.sh && bash tests/test-modules-list.sh && bash tests/test-php-install.sh <x.y>`

## Notes
- Agents run the scripts locally on their own VM (no SSH); each agent IS the
  target. `targetVMs` is required for every mode.
- `update` upgrades whatever stream is currently enabled; it does not change
  the stream. Use `install` to switch streams/versions.