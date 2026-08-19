# tjp-mode

A major mode for editing [TaskJuggler 3](https://taskjuggler.org) project files
(`.tjp`, `.tji`) in GNU Emacs, with syntax highlighting, folding, `xref`
navigation, completion, imenu, eldoc, `tj3` compilation, and project analysis
views.

Requires **Emacs 27.1+**. Compilation, validation and context help additionally
require the TaskJuggler command line tools (`tj3`, `tj3man`).

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Key bindings](#key-bindings)
- [Dependency and successor chains](#dependency-and-successor-chains)
- [Critical path](#critical-path)
- [Navigator](#navigator)
- [Formatting](#formatting)
- [Customization](#customization)
- [Multi-file projects](#multi-file-projects)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)

---

## Features

| Area | What you get |
| --- | --- |
| Highlighting | All TJ3 properties, attributes, dates, times, numbers, macro calls, comments, and `-8<- … ->8-` strings |
| Indentation | Bracket-depth based, with macro bodies and multi-line strings left alone |
| Folding | `hideshow` for both `{ … }` blocks and `[ … ]` macro bodies, plus `outline` patterns |
| Navigation | `xref` backend (`M-.`), imenu, block motion, include-file jumping |
| Completion | `completion-at-point` over keywords and every ID in the project, cached so it stays cheap in large files |
| Documentation | `tj3man` for the keyword at point, falling back to the online manual |
| Compilation | `tj3` through `compile`, with error patterns wired into `compilation-error-regexp-alist`; async syntax check; optional flycheck checker |
| Analysis | Structure navigator, dependency **and successor** chains, **critical path**, resource allocation summary, project statistics |
| Formatting | `tjp-format-buffer` applies the house layout; tj3 ships no formatter of its own |
| Templates | Task / resource / report insertion that nests correctly and follows TJ3's own syntax rules |

## Requirements

* GNU Emacs 27.1 or newer.
* TaskJuggler 3.x for compiling, validating and context help:

  ```sh
  gem install taskjuggler          # provides tj3, tj3man, tj3d, tj3client
  tj3 --version
  ```

* Optional: `company` (completion UI), `flycheck` (on-the-fly checking),
  `yasnippet`, `org` (date picker for `C-c C-d`).

## Installation

The package is two files, `tjp-mode.el` and `tjp-evil.el`. Installing it from
git gives you both, and that is all you need: `tjp-mode` loads `tjp-evil`
itself, and `tjp-evil` stays inert unless evil is present. Nothing has to be
copied into your configuration.

### From source

```bash
git clone https://github.com/jackhale98/tjp-mode.git
```

Add to your init file:

```elisp
(add-to-list 'load-path "/path/to/tjp-mode")
(require 'tjp-mode)
;; .tjp and .tji files auto-activate — no auto-mode-alist needed
```

### use-package

```elisp
(use-package tjp-mode
  :load-path "/path/to/tjp-mode")
```

### straight.el / elpaca

```elisp
;; straight.el
(use-package tjp-mode
  :straight (:host github :repo "jackhale98/tjp-mode"
             :files ("*.el")))

;; elpaca
(use-package tjp-mode
  :ensure (:host github :repo "jackhale98/tjp-mode"
           :files ("*.el")))
```

### package-vc (Emacs 29+)

```elisp
(package-vc-install '(tjp-mode :url "https://github.com/jackhale98/tjp-mode"))
```

### Doom Emacs

Add to `~/.config/doom/packages.el`:

```elisp
(package! tjp-mode
  :recipe (:host github :repo "jackhale98/tjp-mode"
           :files ("*.el")))
```

Add to `~/.config/doom/config.el`:

```elisp
(use-package! tjp-mode
  :mode (("\\.tjp\\'" . tjp-mode)
         ("\\.tji\\'" . tjp-mode)))
```

`tjp-mode.el` already requires `tjp-evil` (`SPC m` keybindings) internally — no
`:config` block needed.

Then run `doom sync`.

### Updating

```bash
cd /path/to/tjp-mode && git pull      # from source
```

`M-x straight-pull-package RET tjp-mode`, `M-x elpaca-update RET tjp-mode`,
`M-x package-vc-upgrade RET tjp-mode`, or `doom upgrade` for the others.

### Optional extras

```elisp
(add-hook 'tjp-mode-hook #'company-mode)   ; completion popup (uses capf)
(add-hook 'tjp-mode-hook #'flycheck-mode)  ; on-the-fly tj3 --check-syntax
(add-hook 'doom-first-file-hook #'auto-insert-mode) ; .tjp file template
```

The `.tjp` template produces a skeleton that compiles as-is — `tj3` needs at
least one task, one resource and a named report, and the template provides all
three.

### Building from a clone

```bash
make compile   # byte-compile, warnings are errors
make lint      # checkdoc
make clean
```

## Quick start

```taskjuggler
project acso "Accounting Software" 2026-01-01 - 2026-12-31 {
  timezone "Europe/Berlin"
  timeformat "%Y-%m-%d"
  currency "EUR"
  outputdir "reports"
}

resource dev "Developers" {
  resource dev1 "Paul Smith" { rate 330.0 }
}

task AcSo "Accounting Software" {
  task spec "Specification" {
    effort 20d
    allocate dev1
  }
  task impl "Implementation" {
    effort 40d
    depends !spec
    allocate dev1
  }
}

taskreport overview "Project Overview" {
  formats html
  columns name, start, end, effort, chart
  loadunit days
}
```

* `C-c C-k` — syntax check (`tj3 --check-syntax`), asynchronously; errors are
  clickable.
* `C-c C-c` — compile.
* `C-c C-v` — compile, then open the report. The output file is named after the
  report's quoted name, so this opens `reports/Project Overview.html`; if the
  project defines several HTML reports you are asked which one.
* `M-.` on `spec` in the `depends` line — jump to the definition, `M-,` back.
* `C-c C-s` — structure browser; `RET` on an entry jumps to it, `q` quits.

## Key bindings

### Vanilla

| Key | Command |
| --- | --- |
| `C-c C-c` | `tjp-compile` |
| `C-c C-v` | `tjp-compile-and-view` |
| `C-c C-k` | `tjp-validate-buffer` |
| `C-c C-n` / `C-c C-p` | `tjp-next-block` / `tjp-previous-block` |
| `C-c C-j` | `tjp-find-include-at-point` |
| `M-.` / `M-,` | `xref-find-definitions` / `tjp-xref-go-back` |
| `C-c C-f` | `tjp-toggle-fold` |
| `C-c C-a` / `C-c C-o` | `tjp-fold-all` / `tjp-unfold-all` |
| `C-c C-i` | `tjp-insert-task` |
| `C-c C-r` / `C-c C-R` | `tjp-insert-resource` / `tjp-insert-report` |
| `C-c C-d` | `tjp-insert-date-prompt` |
| `C-c C-s` | `tjp-toggle-structure` (navigator, toggles) |
| `C-c C-x` | `tjp-toggle-critical-path` |
| `C-c C-y` | `tjp-show-dependencies` (what this task waits for) |
| `C-c C-u` | `tjp-show-successors` (what waits for this task) |
| `C-c C-q` | `tjp-format-buffer` |
| `C-c C-l` | `tjp-show-resource-allocation` |
| `C-c C-=` | `tjp-show-statistics` |
| `C-c C-h` | `tjp-show-help` (tj3man) |
| `C-c C-t` | `tjp-generate-tags` |
| `M-x imenu` | jump to any task / resource / report |

Unbound but available: `tjp-expand-macro-at-point`, `tjp-find-macro-definition`,
`tjp-insert-datetime`, `tjp-insert-date`.

### Evil, Doom and Spacemacs

Everything lives under the `SPC m` major-mode leader, the Doom and Spacemacs
convention. general.el installs it when present (so which-key shows the group
labels); evil users without general get the same tree under the same prefix.
Change it with `tjp-evil-localleader`, or set that to nil for no leader
bindings at all.

Normal state also gets `gd` / `gD` (definition, references), `K` (tj3man),
`]]` / `[[` (block motion) and `za` / `zm` / `zr` (folding). `,` is left alone,
so evil's reverse find-char still works.

| Prefix | Key | Command |
| --- | --- | --- |
| `c` compile | `c` / `v` / `k` | compile / compile & view / validate |
| `g` goto | `n` `p` | next / previous block |
| | `d` `b` | definition / back |
| | `i` `m` | include file / imenu |
| `f` fold | `f` `a` `u` `m` | toggle / fold all / unfold all / `hs-minor-mode` |
| `i` insert | `t` `r` `R` | task / resource / report |
| | `d` `D` | date (picker) / datetime |
| `s` structure | `s` `d` `n` | navigator (toggle) / dependencies / successors |
| | `c` | critical path (toggle) |
| | `a` `=` | resource allocation / statistics |
| `=` format | | `tjp-format-buffer` |
| `M` macro | `e` `d` | expand / goto definition |
| `h` help | `h` `k` | `tj3man` for keyword at point / `describe-mode` |
| `t` tags | `g` `v` | generate / visit tags table |

## Customization

`M-x customize-group RET tjp RET`, or:

| Variable | Default | Meaning |
| --- | --- | --- |
| `tjp-indent-offset` | `2` | Spaces per nesting level (file-local safe) |
| `tjp-compiler-command` | `"tj3"` | Compiler binary; may be an absolute path |
| `tjp-man-command` | `"tj3man"` | Keyword documentation binary |
| `tjp-project-file` | `nil` | Master `.tjp` file this buffer belongs to (file-local safe) |
| `tjp-auto-validate` | `nil` | Run `tj3 --check-syntax` after each save |
| `tjp-follow-includes` | `t` | Scan `include`d files for IDs |
| `tjp-cache-ttl` | `2.0` | Seconds a project scan is reused (raise it for very large projects) |
| `tjp-cleanup-whitespace-on-save` | `t` | Delete trailing whitespace on save, never inside strings |
| `tjp-evil-localleader` | `"SPC m"` | Prefix for the evil leader bindings; nil disables them |
| `tjp-format-on-save` | `nil` | Run `tjp-format-buffer` before every save |
| `tjp-critical-path-report-id` | `"tjpModeCriticalPath"` | ID of the temporary report used for the critical path |

The face `tjp-critical-path` controls the highlight; customize it as usual.

`compile-command` is honoured: set it in `.dir-locals.el` and `C-c C-c` will run
your command instead of the derived one.

## Dependency and successor chains

`depends` and `precedes` describe the same edge from its two ends, so both are
read and both views follow both keywords:

* `C-c C-y` — **dependencies**: what the task at point waits for.
* `C-c C-u` — **successors**: what waits for the task at point.

```
ship:23
├── test:13
│   ├── impl:9
│   │   └── spec:4
│   └── docs:18
│       └── impl:9
│           └── spec:4
└── docs:18
    └── impl:9
        └── spec:4
```

Cycles are marked rather than followed, comma-continued lists spanning several
lines are handled, and `{ gapduration 2d }` style modifiers are ignored. `RET`
or a click on any task jumps to its definition.

## Formatting

`C-c C-q` (`tjp-format-buffer`, `SPC m =`) applies the layout tj3's own
generated files use:

* the delimiters of a multi-line block on their own lines
* one space before a block opener — `task t "T" {`, `macro m [`
* `, ` between the items of a list — `columns name, start, end`
* no trailing whitespace
* one indentation level (`tjp-indent-offset`) per nesting level

A block written entirely on one line — `resource r "R" { rate 10.0 }` — is left
alone, and so are the contents of `-8<- … ->8-` strings and comments. Set
`tjp-format-on-save` to reformat on every save; `tjp-format-region` formats just
the region.

Two things to know: the formatter re-indents by nesting depth, so hand-aligned
continuation lines get flattened to their block's indentation; and it does not
touch spacing inside a line other than lists and block openers.

There is no formatter in the TaskJuggler toolchain to defer to — `tj3` has no
formatting option, and an `export` report with `formats tjp` re-emits the
*scheduled model* (comments gone, macros expanded, `effort` replaced by computed
dates and `booking` blocks), which is a different thing entirely. `tj3
--check-syntax` (`C-c C-k`) remains the syntax linter.

## Critical path

`C-c C-x` (`tjp-toggle-critical-path`, `SPC m s c`) asks tj3 to schedule the
project, then highlights the most critical chain of tasks in the buffer and
marks it in the navigator. Run it again to clear.

```
task spec "Specification" {     ← highlighted
task impl "Implementation" {    ← highlighted
task test "Testing" {           ← highlighted
task docs "Documentation" {
task ship "Ship" {              ← highlighted
```

with `Critical path: spec → impl → test → ship` in the echo area.

**What it actually measures.** TaskJuggler has no slack column, so this is not
the zero-slack critical path of classical CPM. What the scheduler does compute
is `criticalness` (how strained a task's allocated resources are) and
`pathcriticalness` (the criticalness of the whole path through a task).
`pathcriticalness` accumulates downstream — a task's value is its own
criticalness plus that of the most critical path leading away from it — so the
mode starts at the highest value and repeatedly steps to the successor with the
highest value, which walks exactly the path that metric is built from. Container
tasks are stepped over: their criticalness covers everything beneath them and
would otherwise outrank their own children.

**How it runs.** A copy of the project with one extra CSV report appended is
compiled in the background with `--report`, so your own reports are not
regenerated. The report is given an absolute file name, because tj3's `-o` is
only applied when it generates *all* reports — without that, the CSV would land
in your project directory. The copy and its output are deleted afterwards, and
nothing in your project files is touched.

## Navigator

`C-c C-s` (`tjp-toggle-structure`, `SPC m s s`) opens the structure navigator in
a side window, and closes it when it is already open.

```
res    alice (Alice)  :2
task   spec (Specification)  critical  :5
task   impl (Implementation)  critical  :6
task   docs (Documentation)  :8
report crit (crit)  :11
```

`RET` or `mouse-1` **anywhere on a line** jumps to that definition — the whole
line is the link, not just the name — and `q` closes the window. Definitions
written without an ID are listed by name, and tasks on the critical path are
marked once `C-c C-x` has been run. The dependency and successor buffers work
the same way.

## Multi-file projects

A typical layout:

```
project.tjp        # project header, includes, reports
resources.tji
tasks/backend.tji
tasks/frontend.tji
```

`tj3` only accepts a master file whose name ends in `.tjp`, so tell the mode
which file that is:

```elisp
;; .dir-locals.el at the project root
((tjp-mode . ((tjp-project-file . "project.tjp"))))
```

A relative name is searched for in the file's own directory and then upward, so
one `.dir-locals.el` at the root covers every include in every subdirectory.

With that set, from anywhere in the project:

* `C-c C-c` / `C-c C-k` / `C-c C-v` act on the master project.
* `M-.` and completion see every ID in the project, including ones defined in
  sibling include files.
* `C-c C-v` finds reports defined in any file of the project.

Without it, each buffer is treated as its own project — fine for a single-file
`.tjp`, but a `.tji` cannot be compiled on its own.

## Troubleshooting

**`tj3: command not found`.** GUI Emacs does not inherit the `PATH` exported by
your shell. The mode looks in `exec-path` first and then asks your login shell
once (caching the answer), which covers most setups. If it still fails, set the
paths explicitly:

```elisp
(setq tjp-compiler-command "/home/you/.local/share/gem/ruby/3.3.0/bin/tj3"
      tjp-man-command      "/home/you/.local/share/gem/ruby/3.3.0/bin/tj3man")
```

or install [`exec-path-from-shell`](https://github.com/purcell/exec-path-from-shell).

**"tj3 only accepts a .tjp file".** You are in an include file; set
`tjp-project-file` as shown above.

**`C-c C-v` says "No report with `formats html` found".** A report only produces
a file if its block declares `formats html`, and the file is named after the
report's quoted name. Add `formats html` to the report you want to view.

**Errors are not clickable.** The mode matches `file:line: Error: message`,
which is what `tj3` emits when its output is not a TTY. The mode also passes
`--no-color` for good measure.

**Completion feels slow in a huge project.** Raise `tjp-cache-ttl`; the Doom
layer already does this for files over 1 MB.

## Limitations

* Single-quoted TaskJuggler strings (`'…'`) are valid but not highlighted as
  strings — `'` stays punctuation so that apostrophes in ordinary prose do not
  start a string. Double-quoted and `-8<- … ->8-` strings are fully supported.
* `M-.` can only jump to definitions that have an ID (TaskJuggler generates one
  when you omit it, and there is nothing in the file to jump to). ID-less
  definitions still appear in imenu and the structure browser, listed by name.
* Statistics are an estimate computed from the `effort` attributes in the
  current file only, using the project's `dailyworkinghours` and
  `yearlyworkingdays` when they are declared there.
* The dependency and resource-allocation views cover the current buffer, not the
  whole include tree.
* `M-.` needs no tags table — `C-c C-t` exists for tools outside Emacs, and
  writes the table from this mode's own scan (`etags` cannot parse TaskJuggler).

## Files

| File | Purpose |
| --- | --- |
| `tjp-mode.el` | The major mode |
| `tjp-evil.el` | Evil / Doom / Spacemacs keybindings, loaded automatically |
| `Makefile` | `make compile`, `make lint`, `make clean` |
| `LICENSE` | MIT |
| `AUDIT.md` | Audit of the previous version: every bug found, and how it was fixed |

## License

**MIT** — see [LICENSE](LICENSE). Copyright (c) 2025-2026 Jack Hale.

TaskJuggler itself is a separate program under GPL-2.0-only. This mode neither
includes nor links any TaskJuggler code: its keyword tables list the *names* of
TaskJuggler's syntax keywords (generated by `EmacsLispSyntax.rb`, written for
this mode in the style of TaskJuggler's own `VimSyntax.rb`), and its date, time
and number patterns follow the token formats the TaskJuggler language defines.
TaskJuggler's own generated editor-syntax files carry no license notice either.
