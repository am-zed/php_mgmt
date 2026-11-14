# config

## Overview
Declarative PHP module lists partitioned by RHEL version. `rhel-common` holds
shared defaults; `rhel9` and `rhel10` hold per-OS overrides. All lists are
consumed by `../scripts/manage-modules.sh`, which merges them (shared →
OS-specific → runtime) with de-duplication and order preservation.

## Subdirectories & Boundaries
- [rhel-common](./rhel-common/README.md) - shared default module list (all RHEL targets)
- [rhel9](./rhel9/README.md) - RHEL 9 overrides (currently empty)
- [rhel10](./rhel10/README.md) - RHEL 10 overrides (currently empty)