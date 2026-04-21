# increamemo

`increamemo` is an Emacs package for scheduled note review workflows.

This repository currently provides the engineering baseline for the package:

- Eldev-based build and test entrypoints
- ERT regression tests
- lint, byte-compile, and package checks
- GitHub Actions CI
- pre-commit hooks

## Requirements

- Emacs 29.1 or newer
- Eldev
- GNU Make
- pre-commit for local hooks

## Commands

```sh
make bootstrap
make check
make package
pre-commit install
```

## Layout

```text
.
├── .github/
├── docs/
├── scripts/
├── test/
├── Eldev
├── Makefile
└── increamemo*.el
```

## Current Scope

The package currently covers the core scheduling workflow described in the
project docs:

- database initialization and schema migration
- file and EKG note item registration
- due-item ordering, completion, deferral, archiving, skipping, and reprioritization
- work-session progress tracking with transient session state
- board listing, filtering, manual item creation, and row-level item updates
- opener failure handling policies for keep, archive, and delete
