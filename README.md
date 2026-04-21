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

The initial commit establishes configuration gating, SQLite schema initialization,
test scaffolding, and repository automation. Domain workflow features remain as
named module boundaries with explicit placeholders.
