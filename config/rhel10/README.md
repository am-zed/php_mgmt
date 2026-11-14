# rhel10

## Overview
RHEL 10 specific PHP module overrides. Merged on top of
`../rhel-common/modules.list` (de-duplicated, order-preserving) by
`../../scripts/manage-modules.sh`. Currently empty — inherits the common
defaults.

## Interface
- `modules.list` — newline-separated PHP module package names; 0 entries
  (inherits common) [modules.list]
- Read by `manage-modules.sh:read_list` [../../scripts/manage-modules.sh]

## Invariants
- One package name per line [modules.list]
- Empty file inherits all entries from `../rhel-common/modules.list`
  [manage-modules.sh]
- Merged under the runtime `modules` parameter [manage-modules.sh]

## Side Effects
- None (data file; read-only)

## Verification
- Run: `bash ../../tests/test-modules-list.sh` (validates module list format)