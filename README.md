# increamemo

`increamemo` is an Emacs package for scheduled note review.

It keeps a queue of note-like items in SQLite, opens the next due item for focused review, and records every state change in history. The current implementation supports file-backed notes and EKG notes.

## What It Does

- Register the current note as a scheduled item
- Store review state in a local SQLite database
- Open due items in priority order
- Run a focused work session with dedicated review commands
- Provide a board view for browsing, filtering, and editing items
- Handle broken openers with configurable keep, archive, or delete policies

## Requirements

- Emacs 29.1 or newer
- Emacs built with SQLite support
- A writable path for the SQLite database
- Optional: EKG, if you want to register or open EKG notes

## Installation

### Install from Git

Emacs 29 can install the package directly from GitHub:

```elisp
(package-vc-install "https://github.com/JiaJunDeng5930/increamemo")
```

### Install and Configure with `use-package`

If you use `use-package`, you can install `increamemo` from Git and keep the required configuration in one place:

```elisp
(use-package increamemo
  :vc (:url "https://github.com/JiaJunDeng5930/increamemo"
       :rev :newest)
  :custom
  (increamemo-db-file
   (expand-file-name "increamemo.sqlite" user-emacs-directory))
  (increamemo-supported-file-formats '("md" "org" "txt"))
  (increamemo-file-openers
   '(("md" . find-file)
     ("org" . find-file)
     ("txt" . find-file)))
  (increamemo-backends '(increamemo-file-backend))
  :bind (("C-c p w" . increamemo-work)
         ("C-c p b" . increamemo-board)
         ("C-c p a" . increamemo-add-current)))
```

If you use EKG, include its backend in the same declaration:

```elisp
(use-package increamemo
  :vc (:url "https://github.com/JiaJunDeng5930/increamemo"
       :rev :newest)
  :custom
  (increamemo-db-file
   (expand-file-name "increamemo.sqlite" user-emacs-directory))
  (increamemo-backends
   '(increamemo-file-backend increamemo-ekg-backend)))
```

### Load from a Local Checkout

```elisp
(add-to-list 'load-path "/path/to/increamemo")
(require 'increamemo)
```

## Minimal Configuration

Set the database path first. This variable is required for every public command.

```elisp
(setq increamemo-db-file
      (expand-file-name "increamemo.sqlite" user-emacs-directory))
```

The file backend works out of the box for `md`, `org`, and `txt` files:

```elisp
(setq increamemo-supported-file-formats '("md" "org" "txt"))
(setq increamemo-file-openers
      '(("md" . find-file)
        ("org" . find-file)
        ("txt" . find-file)))
```

The package enables two backends by default:

```elisp
(setq increamemo-backends
      '(increamemo-file-backend increamemo-ekg-backend))
```

If you do not use EKG, you can keep only the file backend:

```elisp
(setq increamemo-backends '(increamemo-file-backend))
```

## Optional Configuration

### Priority Schedule Rules for New Items

When you add an item from the current buffer, `increamemo` derives its first
interval and `A-Factor` from `priority`.

```elisp
(setq increamemo-priority-schedule-rules
      '((:max-priority 10 :first-interval-days 1 :a-factor 1.10)
        (:max-priority 30 :first-interval-days 2 :a-factor 1.15)
        (:max-priority 60 :first-interval-days 4 :a-factor 1.25)
        (:max-priority 80 :first-interval-days 14 :a-factor 1.50)
        (:max-priority 100 :first-interval-days 30 :a-factor 2.00)))
```

Each rule applies to priorities up to `:max-priority`. The first matching rule
sets:

- `:first-interval-days`
- `:a-factor`

### Reschedule Policy After Completion

The default policy grows the previous interval with the stored `A-Factor`:

```text
next_interval_days =
  max(ceil(previous_interval_days * a_factor),
      previous_interval_days + 1)

next_due_date = today + next_interval_days
```

You can provide your own function. Two signatures are supported:

```elisp
(setq increamemo-reschedule-function
      (lambda (item action)
        (ignore item action)
        "2026-04-22"))
```

```elisp
(setq increamemo-reschedule-function
      (lambda (item action history-summary today)
        (ignore item action history-summary today)
        "2026-04-22"))
```

The function must return an ISO date string.

### Open Failure Policy

When an item cannot be opened, `increamemo` can keep it as invalid, archive it, or delete it:

```elisp
(setq increamemo-invalid-opener-policy 'keep)
```

Supported values:

- `keep`
- `archive`
- `delete`

### Mode Line Formatter

The default work-session mode line looks like this:

```text
IM[handled/remaining]
```

You can replace it:

```elisp
(setq increamemo-mode-line-format-function
      (lambda (handled remaining)
        (format "Review[%d/%d]" handled remaining)))
```

## First-Time Setup

1. Configure `increamemo-db-file`.
2. Load the package.
3. Run:

```text
M-x increamemo-init
```

`increamemo-init` is safe to run again when you need to create or upgrade the schema.

## Registering Items

### Add the Current Note

Open a supported file buffer or an EKG note buffer, then run:

```text
M-x increamemo-add-current
```

You will be prompted for `Priority:`.

The command:

- identifies the current note through the configured backend list
- creates a scheduled item if it does not already exist
- reuses the existing live item when the same note is already tracked

### Add an Item from the Board

Open the board:

```text
M-x increamemo-board
```

Press `a` and enter:

- `Type`
- `Locator`
- `Opener`
- `Priority`
- `Due date`

Manual item creation uses the backend registry to normalize the locator, choose the default opener, and generate the title snapshot.

Notes:

- For file items, absolute paths are recommended.
- For EKG items, the locator must be a readable Emacs Lisp value such as `42` or `"note-id"`.
- If you leave the opener prompt unchanged, the backend default is used.

## Daily Workflow

### Start a Work Session

```text
M-x increamemo-work
```

The command:

1. finds active items whose due date is today or earlier
2. sorts them by priority, due date, and creation time
3. opens the first due item
4. enables `increamemo-work-mode` in that buffer

If no items are due, Emacs shows:

```text
Increamemo: no due items
```

### Work Session Keys

These keys are available only while `increamemo-work-mode` is active:

```text
C-c , c   Complete and open the next due item
C-c , a   Archive and open the next due item
C-c , d   Defer and open the next due item
C-c , s   Skip for the current session only
C-c , p   Update priority in place
C-c , q   Quit the current work session
C-c , b   Open the board
```

### Work Session Behavior

- `Complete` writes a completion history entry and computes the next due date through the reschedule function.
- `Archive` moves the item to `archived`.
- `Defer` accepts either an ISO date or a day offset such as `3` or `+3`.
- `Skip` writes `skipped` history and removes the item from the current session only.
- `Priority` updates the item in place and keeps the current buffer active.

The session progress shown in the mode line is transient. Closing Emacs and starting a new work session recalculates the remaining due set from the database.

## Board Usage

Open the board:

```text
M-x increamemo-board
```

The board shows these columns:

```text
Type | Due Date | Priority | A-Factor | State | Title
```

### Board Keys

```text
a    Add an item
A    Mark the current row for archive
d    Mark the current row for delete
e    Update the due date
p    Update the priority
t    Show due items
i    Show invalid items
T    Show all items
h    Show archived items
x    Execute the marked row action
g    Refresh
RET  Open the current item
q    Quit the board
```

Extra board commands are available through `M-x`:

- `increamemo-board-show-planned`
- `increamemo-board-show-all`

### Board Filters

- `planned`: active items with a due date
- `due`: active items due today or earlier
- `invalid`: items marked invalid after an open failure
- `all`: active, invalid, and archived items

### Board Actions

The board can:

- add a new item
- mark the current row for archive or delete, then execute with `x`
- update due date
- update priority
- open the current row

When the selected row is stale because the item was changed or removed elsewhere, the board refreshes and shows a direct message instead of operating on the stale snapshot.

## Open Failure Handling

When opening an item fails, Emacs shows a message such as:

```text
Increamemo: failed to open item #42: ...
```

Then the configured failure policy applies:

- `keep`: mark the item as `invalid`
- `archive`: record the failure, then archive the item
- `delete`: record the failure when possible, then remove the item

## Troubleshooting

### `Increamemo: \`increamemo-db-file' is not configured`

Set `increamemo-db-file` before running any public command.

### `Increamemo: database is not initialized; run \`increamemo-init'`

Run:

```text
M-x increamemo-init
```

### `Increamemo: no backend recognized the current buffer`

The current buffer does not match any configured backend. Check `increamemo-backends` and the current buffer type.

### `Increamemo: unsupported file format: ...`

Add the extension to `increamemo-supported-file-formats` and define an opener in `increamemo-file-openers`.

### `Increamemo: missing ekg function: ...`

Load EKG before using EKG items, or remove `increamemo-ekg-backend` from `increamemo-backends`.

## Development

Development setup, local validation, and repository workflow are documented in [CONTRIBUTING.md](./CONTRIBUTING.md).
