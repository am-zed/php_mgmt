# rhel-common

## Overview
Shared default PHP module list applied to all RHEL targets (9 and 10).
Consumed by `../../scripts/manage-modules.sh`, which merges this list with the
OS-specific override (`../rhel<ver>/modules.list`) and the runtime `modules`
pipeline parameter (de-duplicated, order-preserving).

## Interface
- `modules.list` — newline-separated PHP module package names; 15 entries by
  default [modules.list]
- Read by `manage-modules.sh:read_list` [../../scripts/manage-modules.sh]

## Invariants
- One package name per line [modules.list]
- Blank lines and `#` comments (full-line and inline) are ignored —
  `read_list` strips from the first `#` onward [manage-modules.sh:read_list]
- Merged under all OS-specific lists; de-duplicated preserving order
  [manage-modules.sh]

## Side Effects
- None (data file; read-only)

## Verification
- Run: `bash ../../tests/test-mirrors.sh` (config sanity)