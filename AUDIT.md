# tjp-mode audit

Audit of `tjp-mode.el` (1832 lines) and `tjp-mode-doom.el` (189 lines).

Everything below was checked against a real toolchain rather than from memory:
**Emacs 30.1**, **TaskJuggler 3.8.4** (`tj3`, `tj3man`), and the TaskJuggler
sources/manual (`ProjectFileScanner.rb`, `MessageHandler.rb`, `Tj3.rb`,
`reports/Report.rb`, and the `task` / `resource` / `taskreport` / `tagfile` /
`outputdir` manual pages).

Findings are ordered by severity. Each has a reproduction, the fix that was
applied, and its status.

**All 27 findings below were fixed in version 2.2.0.** The file byte-compiles
without warnings, and every reproduction in this document was re-run against
the fixed code: the regression output is quoted in each **Status** line.

One further defect surfaced while fixing the others and is worth recording,
because it is easy to reintroduce: `syntax-ppss' may run
`syntax-propertize-function', which moves point and performs its own searches.
Calling it from inside a `while (re-search-forward ...)' loop - as the scanner,
the imenu index and the whitespace cleanup all do - corrupted the match data and
sent two of those loops spinning forever. All such calls now go through
`tjp--in-string-or-comment-p', `tjp--in-string-p' or `tjp--nesting-depth', which
wrap `syntax-ppss' in `save-excursion' and `save-match-data'.

---

## Correctness bugs

### B1 — `C-c C-v` (compile and view) can never open the report

`tjp--first-report-id` (`tjp-mode.el:1576`) captures the report **ID** and
`tjp-compile-and-view` (`tjp-mode.el:1598`) looks for `<id>.html`. TaskJuggler
names the output file after the report's **quoted name**:

> `taskreport [<id>] <name> [{ <attributes> }]` — the name is "the base name for
> generated output files. The suffix will depend on the specified formats."

Verified with tj3 3.8.4:

```
taskreport overview "Project Overview" { formats html … }
$ tj3 --silent project.tjp
$ ls
'Project Overview.html'          # not overview.html
```

Two failure modes follow:

* With an ID present, the command always reports *"Report output not found"*.
* Because the ID is optional, `taskreport "Overview" { … }` is not matched by the
  regexp at all and the command aborts with *"No report definition found in this
  buffer"*. Confirmed on a sample file where the first report was ID-less: the
  function silently returned the *second* report's ID.

**Fix.** Capture the quoted name: `^\s-*<report-kw>\s-+\(?:[a-zA-Z_][a-zA-Z0-9_]*\s-+\)?"\([^"]+\)"`.
Collect all reports and, when there is more than one, `completing-read` which to
open. Check that the report's block actually contains `formats` with `html`
before predicting a `.html` file. Names beginning with `/` are absolute and must
not be joined with `outputdir` (`Report.rb`, `absoluteFileName`).

**Status: fixed** in 2.2.0 - report output is now derived from the report's quoted name, the optional ID is handled, `formats html` is required, and a project with several HTML reports prompts. Verified against tj3 3.8.4: predicted path == generated file, in a single-file and in a multi-file project.

### B2 — Insertion templates can emit invalid TaskJuggler

For `task`, `resource`, `account` and every report type the syntax is
`keyword [<id>] <name>` — **ID optional, name mandatory** (manual, `task.html`
and `resource.html`; "if no ID is specified, one will be automatically
generated").

`tjp-insert-task` / `tjp-insert-resource` / `tjp-insert-report`
(`tjp-mode.el:1674`–`1716`) prompt for a mandatory ID and an *optional* name,
and `tjp--block-header` (`tjp-mode.el:1668`) drops the name when it is empty:

```elisp
;; batch reproduction: ID "t9", empty name
"task t9 {\n  \n}\n"        ; tj3: syntax error, name expected
```

**Fix.** Prompt for the name first and require it; make the ID prompt optional
and emit `keyword id "name"` only when an ID was given. For reports, relabel the
prompt — that string is the *output file base name*, not a cosmetic title.

**Status: fixed** in 2.2.0 - the name is now prompted for first and required; the ID is optional and omitted when empty.

### B3 — The Doom auto-insert template produces a project that will not compile

`tjp-mode-doom.el:168` inserts `taskreport overview "" { formats html … }`.
Verified:

```
$ tj3 --silent doom-template.tjp
doom-template.tjp:14: Error: Report overview has output formats requested,
                             but the file name is empty.
$ echo $?
1
```

**Fix.** Emit a real name, e.g.
`taskreport overview "Project Overview" {`, ideally prompting for it like the
other template fields. Note also that Doom does not enable `auto-insert-mode`, so
the template never fires unless the user opts in — worth a comment in the file.

**Status: fixed** in 2.2.0 - the template now emits a named report plus a starter resource and task, and compiles with exit status 0.

### B4 — Compile and validate cannot work on `.tji` files

The mode claims `.tji` support and binds compile/validate in those buffers, but
`tj3` refuses non-`.tjp` input:

```
$ tj3 --check-syntax --silent part.tji
part.tji:0: Error: Project file name must end with '.tjp' extension
```

`tjp-compile` (`tjp-mode.el:1548`) and `tjp-validate-buffer`
(`tjp-mode.el:1386`) always pass `buffer-file-name`.

**Fix.** Add a `tjp-project-file` defcustom (safe as a file/dir-local variable),
default `nil` meaning "this buffer"; compile that file when set. The same
setting solves U14 (upward include scanning).

**Status: fixed** in 2.2.0 - new `tjp-project-file' option (file/dir-local safe, searched upward from the buffer); compile, view and validate all act on the master project.

### B5 — `M-.` can jump to the wrong definition

`tjp--find-id-in-cache` (`tjp-mode.el:689`) falls back to
`(string-suffix-p id (car entry))` with no boundary check:

```elisp
(tjp--find-id-in-cache "ev")   ;; => ("dev" "resource" 8 9 …)
```

Any identifier that happens to be a suffix of another resolves to the wrong
property; `C-c C-v`-style silent misnavigation is worse than no navigation.

**Fix.** Require a dot boundary: `(string-suffix-p (concat "." id) key)`. When
several entries match, return them all — `xref-backend-definitions` may return a
list and let the user choose.

**Status: fixed** in 2.2.0 - exact match, then last-component match for dotted references, then a `.ID' suffix match. `ev' no longer resolves to `dev'.

### B6 — Indentation is corrupted by macro bodies and `-8<-` strings

`tjp--calculate-indent` (`tjp-mode.el:570`) derives indentation purely from
`syntax-ppss` depth. Braces inside a macro body or inside a scissors string are
counted as real nesting. Reproduced with `indent-region`:

```taskjuggler
macro open [
  task ${1} "${2}" {      ← deliberately unbalanced, the point of the macro
]
task a "A" {              ← indented to column 2 by the mode
  effort 1d               ← column 4
}
```

The same happens for `note -8<- … Use { to open a block … ->8-`; every line after
the string is shifted a level.

Additionally, `indent-region` **rewrites the interior of a scissors string**. Per
`ProjectFileScanner.rb`, "the indentation of the first line after the opening
mark determines the indentation for all following lines", so reindenting changes
the string's value.

**Fix.** Add a `syntax-propertize-function` that marks `-8<- … ->8-` as a
generic string (`|`) and macro bodies as a comment/string-like region, then have
`tjp-indent-line` return `'noindent` when `(nth 8 (syntax-ppss))` is non-nil.

**Status: fixed** in 2.2.0 - new `tjp-syntax-propertize': scissors strings become generic strings and unbalanced brackets inside macro bodies are neutralised; `tjp-indent-line' returns `noindent' inside a string.

### B7 — Scissors-string highlighting degrades while typing

The `-8<-` rule (`tjp-mode.el:462`) is a multiline regexp with no
`font-lock-multiline` property and no syntax-propertize support, so jit-lock's
single-line refontification loses it. Reproduced by editing a line inside the
block and refontifying only that line:

```
before edit:  font-lock-string-face
after edit:   font-lock-keyword-face
```

**Fix.** Same syntax-propertize approach as B6 (preferred), or at minimum
`(setq-local font-lock-multiline t)` and a matcher function.

**Status: fixed** in 2.2.0 - same syntax-propertize change - the block is a real string to the syntax layer, so a partial refontification keeps string face.

### B8 — `save-buffer` runs before the `buffer-file-name` check

`tjp-compile` (`tjp-mode.el:1548`), `tjp-compile-and-view` (`:1598`) and
`tjp-validate-buffer` (`:1386`) all call `(save-buffer)` first and only then
test `buffer-file-name`, so the intended message *"Buffer has no file name"* is
unreachable — Emacs prompts for a file name instead. (Reproduced: the batch test
hung on the prompt.)

**Fix.** Test `buffer-file-name` first, then `(save-buffer)`. Consider
`(save-some-buffers t)` so includes are saved too, since `tj3` reads them from
disk.

**Status: fixed** in 2.2.0 - the target is resolved (and may fail) before anything is saved, and saving now uses `save-some-buffers' so includes are written too.

### B9 — `C-c C-t` generates a meaningless `TAGS` file

`tjp-generate-tags` (`tjp-mode.el:992`) shells out to `etags`, which has no
TaskJuggler support. On the sample project it produced four bogus tags from a
`columns` line and not a single task or resource:

```
sample.tjp,131
  columns name,40,760
  columns name, start,40,760
  …
```

It then calls `visit-tags-table`, which changes `M-.` behaviour for *every*
buffer. TaskJuggler's own `tagfile` report emits classic ctags format, which
Emacs 30 rejects outright (`"File tags is not a valid tags table"` — verified).

Two further defects in the same function: it errors on a buffer without a file
(`file-name-directory` of `nil`), and it scans from the current file's directory
rather than the project root.

**Fix.** Delete the command — the built-in xref backend already does this job
better — or generate an etags-format table from `tjp--scan-file`'s output.

**Status: fixed** in 2.2.0 - `tjp-generate-tags' now writes an etags-format table from the mode's own project scan; `visit-tags-table' accepts it.

### B10 — Block motion stops on attribute lines

`tjp-next-block` / `tjp-previous-block` (`tjp-mode.el:1520`, `:1532`) search over
`tjp-block-keywords`, which includes `allocate`, `columns`, `depends`, `date`,
`include`, `limits`, `number`, `text`, `richtext` … Observed stops while walking
the sample file:

```
resource dev "Developers" {
  allocate dev1          ← not a block
  allocate dev2          ← not a block
  columns name, start …  ← not a block
```

**Fix.** Introduce a `tjp-structural-keywords` list (`project`, `task`,
`resource`, `account`, `shift`, `scenario`, `macro`, `supplement`, and the report
types) and use it for motion; keep `tjp-block-keywords` for whatever else needs
the wider set.

**Status: fixed** in 2.2.0 - block motion uses the new `tjp-structural-keywords' and skips matches inside strings and comments.

### B11 — eldoc hooks the wrong variable

`tjp-mode.el:1799`:

```elisp
(add-function :before-until (local 'eldoc-documentation-function) #'tjp-eldoc-function)
```

Since Emacs 28, `eldoc-documentation-function` is a **`defvaralias` for
`eldoc-documentation-strategy`** (`eldoc.el`, `eldoc--documentation-strategy-defcustom`).
The mode is therefore advising the *strategy*, not a documentation backend. It
does display (verified — `("Attribute: effort" :origin …)` reaches
`eldoc-display-functions`), but it silently replaces any strategy the user
configured (Doom users commonly set `eldoc-documentation-compose`) and suppresses
every other eldoc source whenever `tjp-eldoc-function` returns a string.

**Fix.**

```elisp
(add-hook 'eldoc-documentation-functions #'tjp-eldoc-function nil t)
```

**Status: fixed** in 2.2.0 - the mode adds `tjp-eldoc-function' to `eldoc-documentation-functions'.

### B12 — `-` as a symbol constituent breaks identifier detection

`tjp-mode-syntax-table` (`tjp-mode.el:513`) declares `-` a symbol constituent
"to allow hyphens in identifiers", but TaskJuggler IDs are `[a-zA-Z_]\w*`
(`ProjectFileScanner.rb`) and never contain `-`. Consequence:

```elisp
;; point inside 2002-01-16
(tjp--get-id-at-point) ;; => "2002-01-16"
```

so `tjp-show-help` (`K` in Doom) runs `tj3man 2002-01-16` → *"No matches found"*,
and eldoc/completion/xref all operate on dates and hyphenated prose.

**Fix.** Drop the `-` entry; keep `.` for hierarchical IDs.

**Status: fixed** in 2.2.0 - `-' is punctuation again; point inside `2002-01-16' no longer yields the whole date as an identifier.

### B13 — Definitions without an ID are invisible

`tjp--definition-regexp` (`tjp-mode.el:616`), `tjp--imenu-create-index` (`:723`),
`tjp-show-structure` (`:1053`) and the statistics scanner all require
`keyword <id>`. Since the ID is optional, ID-less definitions vanish. Verified —
neither `task "Unnamed ID task"` nor `resource "No ID Resource"` appears in the
imenu index.

**Fix.** Make the ID group optional and fall back to the quoted name as the label
(imenu/structure). xref cannot jump to something with no ID, but the browser and
the statistics should still count it.

---

## Usability, performance and hygiene

**Status: fixed** in 2.2.0 - the ID is optional in the definition, index and report regexps; imenu and the structure browser label ID-less definitions by name.

### U1 — Completion rescans the whole project on every call

`tjp-completion-at-point` (`tjp-mode.el:823`) calls `tjp--update-xref-cache`
unconditionally. Measured on a generated 12,001-line project (3,000 tasks):

```
xref-cache scan      0.097 s
completion-at-point  0.102 s
```

With `company-mode`'s idle completion that is a ~100 ms hitch after each
keystroke. `tjp--xref-cache-timestamp` exists but is never read.

**Fix.** Cache per buffer keyed on `(buffer-chars-modified-tick)` plus the
include files' mtimes, which the on-disk cache already tracks.

**Status: fixed** in 2.2.0 - the scan is cached per buffer on `(buffer-chars-modified-tick)' with a `tjp-cache-ttl' bound. 20 consecutive completions in the 12k-line project: 0.003 s total, down from ~2 s.

### U2 — Opening a file creates a directory as a side effect

`tjp-setup-snippets` (`tjp-mode.el:1507`) runs on every `tjp-mode` activation and
does `make-directory ~/.emacs.d/snippets/tjp-mode` whether or not the user wants
it, adds it to `yas-snippet-dirs` without calling `yas-reload-all` (so it has no
effect in the running session), and the repository ships no snippets.

**Fix.** Remove it, or ship a `snippets/` directory and register it once at load
time behind a defcustom.

**Status: fixed** in 2.2.0 - `tjp-setup-snippets' removed.

### U3 — Analysis buffers are not `special-mode`

`*TJ Structure*`, `*TJ Dependencies*`, `*TJ Resource Allocation*` and
`*TJ Statistics*` are plain fundamental-mode buffers; `q` does not bury them and
`*TJ Statistics*` is not even read-only. `tjp--source-buffer` is set in two of
them (`:1062`, `:1319`) and never read.

**Fix.** Derive a small `tjp-report-mode` from `special-mode`, use it for all
four, and delete `tjp--source-buffer`.

**Status: fixed** in 2.2.0 - new `tjp-report-mode' (derived from `special-mode') backs all four buffers; `q' works and they are read-only.

### U4 — Unconditional whitespace deletion on save

`tjp-cleanup-whitespace` is added to `before-save-hook` (`tjp-mode.el:1807`)
with no way to opt out short of removing the hook, and it strips trailing
whitespace inside `-8<-` strings, i.e. it edits data.

**Fix.** Gate it behind a `tjp-cleanup-whitespace-on-save` defcustom (default
`nil` is the conservative choice) and skip regions inside strings.

**Status: fixed** in 2.2.0 - new `tjp-cleanup-whitespace-on-save' option, and the cleanup skips anything inside a string.

### U5 — Blocking subprocesses

`tjp-validate-buffer` and `tjp-show-help` use synchronous `shell-command`, which
freezes Emacs for the duration. `tj3 --check-syntax` on a large project is not
instantaneous, and with `tjp-auto-validate` enabled it runs after every save.

**Fix.** Use `compile`/`compilation-start` (which also gives you the error
regexps for free) or `make-process` with a sentinel.

**Status: fixed** in 2.2.0 - validation runs through `compilation-start' in `*TJ Validation*'.

### U6 — Inconsistent and noisy `PATH` handling

`tjp--shell-command-with-path` (`tjp-mode.el:115`) wraps commands in
`$SHELL -lc "<cmd>"`, and the result is then handed to `compile`/`shell-command`,
which runs it through `shell-file-name` — a shell inside a shell. A login shell
also prints profile/motd output into the `*compilation*` buffer. Meanwhile
`tjp-show-help` bypasses the wrapper entirely: it uses `executable-find`, so
under a GUI Emacs without the gem bin directory on `exec-path` it silently falls
back to opening the website.

**Fix.** Drop the wrapper; document `exec-path-from-shell` and absolute paths in
`tjp-compiler-command` / `tjp-man-command` (the README does this). If the wrapper
is kept, apply it consistently and use `-c`, not `-lc`.

**Status: fixed** in 2.2.0 - the login-shell wrapper is gone; `tjp--resolve-command' checks `exec-path' and falls back to asking the login shell once, caching the result.

### U7 — `compile-command` is set but never used

The mode sets a buffer-local `compile-command` (`tjp-mode.el:1780`) that
`tjp-compile` ignores, so customizing it — the ordinary Emacs idiom, and the
natural workaround for B4 — has no effect on `C-c C-c`.

**Fix.** Have `tjp-compile` run `compile-command` (recomputing it when the file
name changes), or drop the variable.

**Status: fixed** in 2.2.0 - `tjp-compile' runs `compile-command' when the user or `.dir-locals.el' has set it, and otherwise derives and stores the command.

### U8 — Folding gaps

`tjp-setup-hideshow` (`tjp-mode.el:876`) registers only `{`/`}` and `#`. Macro
bodies (`[ … ]`) are unfoldable — verified: `C-c C-f` on `macro m [` reports
*"No block found at point"* and creates no overlay — and `//` and `/* */`
comments are not declared to hideshow. `tjp-toggle-fold`'s fallback
`search-backward "{"` also finds braces inside comments and strings.

**Status: fixed** in 2.2.0 - hideshow now knows `[' and `]' and both comment syntaxes; `tjp-toggle-fold' finds the enclosing bracket via `syntax-ppss' instead of a blind backward search.

### U9 — `tj3man` invocation

`tjp-show-help` (`tjp-mode.el:853`) interpolates the keyword into a shell command
without `shell-quote-argument`, and omits `--silent`, so every lookup is preceded
by eight lines of version banner (verified; `tj3man --silent effort` is clean).
It also queries whatever symbol is at point, including numbers and dates.

**Fix.** Quote the argument, pass `--silent`, and when the symbol is not in
`tjp--all-keywords` prompt with completion over that list instead.

**Status: fixed** in 2.2.0 - `tjp-show-help' uses `call-process' with `--silent', and prompts with completion over the keyword list when point is not on a keyword.

### U10 — Statistics are approximate in undocumented ways

`tjp-show-statistics` (`tjp-mode.el:1420`) counts `\bmilestone\b` anywhere,
including inside comments and strings, matches `effort` in report and `limits`
contexts, and converts with hard-coded factors (8 h/day, 5 d/week, 20 d/month,
240 d/year) instead of the project's `dailyworkinghours` and
`yearlyworkingdays` (TaskJuggler's default is 260.714 working days/year).

**Fix.** Read the project's own settings when present, restrict the scan to task
contexts, and label the output as an estimate.

**Status: fixed** in 2.2.0 - conversion uses the project's `dailyworkinghours' and `yearlyworkingdays'; counts are anchored to statements and skip strings and comments; the buffer states its basis.

### U11 — Dead code and byte-compile warnings

* `tjp-indent-keywords` (`:522`, 48 entries) — unused since indentation moved to
  `syntax-ppss`; a duplicate of `tjp-block-keywords`.
* `tjp-error-regexp-alist` (`:952`) — superseded by `tjp-setup-compilation`.
* `tjp--xref-cache-timestamp` (`:607`) — written, never read.
* `tjp--source-buffer` (`:1148`) — set twice, never read.
* `tjp-insert-date` — reachable only as a fallback inside
  `tjp-insert-date-prompt`; not bound anywhere.

`emacs -Q --batch -f batch-byte-compile tjp-mode.el` reports:

```
tjp-mode.el:1062:13: assignment to free variable ‘tjp--source-buffer’
tjp-mode.el:1207:23: reference to free variable ‘tjp-nav-button-map’
tjp-mode.el:1514:21: reference/assignment to free variable ‘yas-snippet-dirs’
tjp-mode.el:1045:20: the function ‘org-read-date’ is not known to be defined
```

Move `defvar-local tjp--source-buffer` and `defvar tjp-nav-button-map` above
their first use, and add `(declare-function org-read-date "org")` /
`(defvar yas-snippet-dirs)`.

**Status: fixed** in 2.2.0 - all five removed and the four warnings fixed; `emacs -Q --batch -f batch-byte-compile tjp-mode.el' is now silent.

### U12 — Keyword-list gaps and misclassifications

Diffed the mode's 248 completion keywords against `tj3man`'s own list of 209
documented keywords. Genuine keywords missing from the mode (each confirmed with
`tj3man --silent <kw>`):

```
startcredit  endcredit  leaveallowance  projection
disabled     enabled    interval1  interval2  interval3  interval4
```

(The remaining diff entries — `columnid`, `functions`, `logicalexpression`,
`properties` — are manual sections, not keywords; and most of the mode's extra
entries are legitimate column IDs such as `wbs`, `revenue`, `headcount`.)

Misclassifications: `tagfile` and `icalreport` define top-level reports but sit
in `tjp-attributes`, so they get attribute face instead of property face, and
`tjp--report-keywords` (used by `tjp-insert-report` and B1) omits `tagfile`.

`"@"` in `tjp-attributes` can never match — `regexp-opt … 'words` wraps it in
`\<…\>` — but it does show up as a completion candidate.

Finally, the syntax table comment at `tjp-mode.el:500` states "TaskJuggler only
has double-quoted strings". `ProjectFileScanner.rb` defines single-quoted
multi-line strings as well (`startStringSQ` / `endStringSQ`). The current choice
(`'` as punctuation) is the safer one for prose containing apostrophes, but the
comment should say so rather than assert something inaccurate, and `'…'` strings
will not be highlighted.

**Status: fixed** in 2.2.0 - the ten missing keywords were added, `tagfile' and `icalreport' moved to the property list, `@' dropped, and the syntax-table comment corrected.

### U13 — Doom layer nits

* `xref-pop-marker-stack` (`tjp-mode-doom.el:56` and `:104`, and `tjp-mode.el:1733`) is
  obsolete since Emacs 29.1 in favour of `xref-go-back`.
* `projectile-globally-ignored-file-suffixes ".tjx"` — TaskJuggler 3 emits
  `.html`, `.csv`, `.tjp`, `.ics`, `.xml`; there is no `.tjx`.
* `(add-hook 'tjp-mode-hook 'eldoc-mode)` duplicates what the mode already does
  (`tjp-mode.el:1799`).
* The large-file hook disables flycheck and hideshow but not the actual cost in
  big buffers (U1).
* `(add-to-list 'projectile-project-root-files "project.tjp")` changes project
  detection globally; harmless but worth a comment.

**Status: fixed** in 2.2.0 - `tjp-xref-go-back' picks the right command per Emacs version, the `.tjx' entry is gone, the duplicate eldoc hook is gone, and the large-file hook raises `tjp-cache-ttl'.

### U14 — Includes are followed downward only

`tjp--collect-all-defs` (`tjp-mode.el:663`) walks from the current file into its
includes. Editing a `.tji`, you get no IDs from the master project — which is
where `project`, resources and shared macros usually live. The `tjp-project-file`
setting proposed in B4 fixes both.

---

## Found while fixing

Two more defects turned up when the fixed commands were exercised end to end.

### B14 - `C-c C-j` opened the include file and then left it

`tjp-find-include-at-point` wrapped its whole body in `save-excursion`, which
restores the current *buffer* as well as point - so `find-file` ran, and control
returned to the original buffer immediately. The jump silently did nothing.
Verified: after the command, `buffer-file-name` was still the original file.

**Status: fixed** in 2.2.0 - the search is factored into `tjp--include-at-point`
(which keeps its `save-excursion`) and the jump happens outside it. After the
command the current buffer is `resources.tji`, as it should be.

### B15 - macro expansion stopped at the first `]`

`tjp-expand-macro-at-point` matched `\[\(.*?\)\]` non-greedily, so a body
containing a bracket - `celltext.task 1 "x [1] y"` - was truncated at that
bracket. The tj3 scanner ends a macro body at the first `]` that ends a line.

**Status: fixed** in 2.2.0 - both macro commands now share `tjp--find-macro`,
which applies the end-of-line rule; the example above expands in full.

## What held up well

Worth stating, since the list above is long - these were checked and left alone:

* The error regexps match reality. `MessageHandler#to_s` emits
  `<file>:<line>: Error: <message>`, and `Tj3AppBase` sets
  `Term::ANSIColor.coloring = STDOUT.tty?`, so under `compile` (a pipe) there are
  no escape sequences to defeat the pattern. Verified end to end.
* `--silent`, `--check-syntax`, `-o/--output-dir` and the `outputdir` project
  attribute all exist and behave as the mode assumes (`Tj3.rb`, manual).
* The online help fallback URL (`taskjuggler.org/tj3/manual/<keyword>.html`) is
  correct.
* Include scanning memoizes by mtime, prefers live buffers over disk, and
  detects cycles — the design is right, only the invalidation trigger (U1) is
  missing.
* Indentation via `syntax-ppss` rather than a keyword table is the right call;
  B6 is about the syntax layer, not the algorithm.
* Font-lock does not clobber string contents: keyword rules run without an
  override flag, so `#` and `3d` inside a quoted string keep string face
  (verified — a plausible-looking bug that is not one).
* `:exclusive 'no` on the capf, buffer-local `xref-backend-functions`, and
  `add-to-list` for the compilation patterns are all correct, well-behaved
  choices.

**Status: fixed** in 2.2.0 - scanning starts from `tjp-project-file' when set, so an include sees the whole project's IDs.

