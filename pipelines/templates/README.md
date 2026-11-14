# pipelines/templates

## Overview
Azure Pipelines step and job templates that compose the manual PHP management
workflow. The job template (`php-mgmt-job.yml`) expands one job per target VM
(pinned by an `Agent.Name` demand) and selects steps by `mode`. Every action
step (install/update/remove/switch/verify) is gated on the `mirrorsReady`
variable set by the mirror-check step, while the audit step always runs
(read-only). All mutations are delegated to `../scripts/` — the templates
contain no imperative logic.

## Interface
- `php-mgmt-job.yml` — job template; parameters `mode`, `phpVersion`,
  `modules`, `targetVMs`, `poolName`, `setAsDefault`, `outputFormat`; expands
  per-VM jobs via `split(targetVMs, ",")` with `demands: Agent.Name -equals`;
  mode-based step selection [php-mgmt-job.yml]
- `check-mirrors.yml` — step template; runs `../../scripts/check-mirrors.sh`;
  sets `mirrorsReady` [check-mirrors.yml]
- `install-php.yml` — step template; param `phpVersion`;
  `condition: mirrorsReady=='true'`; runs `install-php.sh` [install-php.yml]
- `manage-modules.yml` — step template; param `modules`;
  `condition: mirrorsReady=='true'`; runs `manage-modules.sh`
  [manage-modules.yml]
- `switch-php-default.yml` — step template; param `phpVersion`;
  `condition: mirrorsReady=='true'`; runs `switch-php-default.sh`
  [switch-php-default.yml]
- `update-php.yml` — step template; `condition: mirrorsReady=='true'`; runs
  `update-php.sh` [update-php.yml]
- `remove-php.yml` — step template; param `modules`;
  `condition: mirrorsReady=='true'`; runs `remove-php.sh` [remove-php.yml]
- `audit-php.yml` — step template; param `outputFormat`; NOT gated; runs
  `audit-php.sh` [audit-php.yml]
- `verify.yml` — step template; param `phpVersion`;
  `condition: mirrorsReady=='true'`; runs `../../tests/test-php-install.sh`
  [verify.yml]

## Invariants
- `check-mirrors.yml` runs first in every non-audit mode
  [php-mgmt-job.yml: `ne(parameters.mode, 'audit')`]
- Action steps (install/update/remove/switch/verify) gated on
  `eq(variables['mirrorsReady'], 'true')` [each template `condition:`]
- `audit-php.yml` is never gated — read-only, always reports [audit-php.yml]
- Each VM → exactly one job, pinned via
  `demands: Agent.Name -equals ${{ trim(vm) }}` [php-mgmt-job.yml]
- Pipeline trigger is manual only (`trigger: none`, defined in root
  `azure-pipelines.yml`) [../../azure-pipelines.yml:13]

## Side Effects
- Delegates all system mutations to `../scripts/*.sh` (templates contain no
  imperative mutations)
- Sets job variable `mirrorsReady` [check-mirrors.yml]

## Verification
- Run: `bash ../../tests/test-mirrors.sh && bash ../../tests/test-php-install.sh <x.y>`