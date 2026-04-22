# Contributing

This document covers local development for `increamemo`.

`README.md` is the user guide. This file covers repository setup, validation, and maintenance work.

## Requirements

- Emacs 29.1 or newer
- GNU Make
- Git
- Python with `pre-commit`
- Eldev

## Bootstrap

Install Eldev and prepare dependencies:

```sh
make bootstrap
```

If Eldev is not already available in your `PATH`, the repository includes a helper script used by CI:

```sh
./scripts/install-eldev.sh "$HOME/.local/bin"
```

## Common Commands

### Full Verification

```sh
make check
pre-commit run --all-files
```

`make check` runs:

- compile
- lint
- test
- package

### Individual Targets

```sh
make compile
make lint
make test
make package
make precommit
make doctor
make clean
```

## Continuous Integration

GitHub Actions runs:

```sh
make ci
```

That target runs the full check suite and then:

```sh
pre-commit run --all-files
```

## Repository Layout

```text
.
├── .github/workflows/ci.yml
├── docs/
├── scripts/
├── test/
├── increamemo.el
├── increamemo-*.el
├── Makefile
└── Eldev
```

Important areas:

- `increamemo.el`: public entrypoints
- `increamemo-domain.el`: state transitions and history approval
- `increamemo-storage.el`: SQLite access
- `increamemo-migration.el`: schema creation and upgrades
- `increamemo-work.el`: work-session runtime
- `increamemo-board.el`: board runtime
- `increamemo-backend*.el`: backend integration
- `test/`: ERT regression tests

## Development Rules

### Keep Responsibilities Separated

- Domain logic belongs in `increamemo-domain.el`.
- SQLite calls belong in `increamemo-storage.el`.
- Schema logic belongs in `increamemo-migration.el`.
- Open side effects belong in `increamemo-opener.el`.
- Runtime UI behavior belongs in `increamemo-work.el` and `increamemo-board.el`.
- Backend-specific logic belongs in the backend modules.

### Add Tests for Non-Trivial Changes

The test suite is organized by behavior area:

- `test/increamemo-add-current-test.el`
- `test/increamemo-board-test.el`
- `test/increamemo-complete-test.el`
- `test/increamemo-domain-test.el`
- `test/increamemo-failure-test.el`
- `test/increamemo-work-test.el`
- additional backend, storage, migration, and static checks

Add or update tests when changing:

- state transitions
- history semantics
- failure handling
- backend contracts
- key runtime flows

### Keep Documentation Split

- `README.md` explains installation, configuration, and usage.
- `CONTRIBUTING.md` explains local development.

User-facing documentation in this repository is written in English.

## Design Documents

The repository includes two local design references:

- `e2e.md`
- `architecture.md`

They are used for implementation alignment. Keep them out of commits. Exclude them locally through `.git/info/exclude`.

## Before Sending Changes

Run:

```sh
make check
pre-commit run --all-files
```

Check these points before submitting work:

- commands in docs still match the repository
- tests cover the changed behavior
- new public behavior is documented in `README.md`
- contributor workflow notes stay in `CONTRIBUTING.md`
