# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

GITLAK fork of TurboPack SynEdit (upstream `https://github.com/TurboPack/SynEdit`).
Scope: **Delphi 13+**, built for Win32 and Win64, installed into the 64-bit RAD Studio IDE. Upstream
content is unmodified except where entries below say otherwise, so the fork delta stays
visible.

## [Unreleased]

### Changed

- Codeberg is retired; every repository URL points at GitHub again (2026-09-05).
  **Why:** hosting consolidated back on GitHub. `origin` is the GitHub URL, the stale
  `codeberg` remote has been removed from the working checkout, and the documentation that
  says where to clone from was updated to match. The Codeberg entry below is superseded;
  its URLs are left as written because rewriting them would falsify the record.

- Repository moved to the `GITLAK-forks` Codeberg organisation: `origin` is now `https://codeberg.org/GITLAK-forks/gllSynEdit.git`. **Why:** the `GITLAK` account had reached Codeberg's hard limit of 100 repositories, and an organisation carries its own allowance (2026-09-03)
  **Superseded 2026-09-05:** Codeberg is no longer used; see the entry above.

## [In-Service]

> Libraries and packages are continuously deployed: changes below are live as soon as the package is rebuilt and installed - there is no separate release step, so no `[Unreleased]` backlog. Tagged version snapshots are listed beneath.

### Changed

- **The pre-D13 package folders were removed** (2026-08-28) — `Packages/Berlin`, `Packages/Rio`, `Packages/Sydney`, `Packages/Tokyo`, 60 files.
  They are pre-D13 and built nothing here, so under the Delphi 13+ rule they carried no weight.
  Upstream still ships all four and last touched them on 2026-06-05, so a future merge that changes any of those files will raise a delete/modify conflict. **Resolve it by keeping the deletion** — `git rm` the path. That cost was accepted knowingly; `CLAUDE.md` records it so the conflict is recognised rather than reverted.
  (An intermediate commit restored these folders in error before the intent was confirmed; `dda0d72` restored them and this removes them again deliberately.)

- **`CLAUDE.md` added** (2026-08-28) — `CLAUDE.md`. The fork's rules lived only in `readme.md` and `CHANGELOG.md`, so the things most likely to bite were not written down anywhere a reader would look first.
  It records the scope (Delphi 13+, Win32 + Win64, never Win64x, C++Builder never in scope), the merge-never-rebase rule and why mass edits are far costlier here than in `glldzlib` — this fork has real git ancestry with upstream, so every edit to an upstream file is a future conflict, whereas `glldzlib` is an SVN snapshot.
  It also records the `TSynNativeInt` trap in full, since that is the one thing about this codebase that a Win32-only build will never reveal, and — at that point — a decision **not** to delete the pre-D13 `Packages/Berlin|Tokyo|Rio|Sydney` folders. **That decision was reversed the same day**: they were removed because they are not needed for D13+, see the entry above. What survives from it is the merge consequence, which is real either way: upstream still ships all four and last touched them on 2026-06-05, so a merge touching them raises a delete/modify conflict that must be resolved by keeping the deletion.

- `upstream/master` is merged as far as `ee3c6ba` (2026-08-27). Its three commits were cherry-picked on 2026-08-22 (the accidental "Import IDE Settings" guard), so the merge changes no file - `git diff` against the pre-merge tree is empty and there was nothing to conflict. It exists because this fork takes upstream by merging, and an unrecorded merge leaves `git rev-list` reporting a backlog that is not there. `README.md` now carries the merged-through marker beside the merge-never-rebase rule, so the position is readable without running git.

### Fixed

- **Two `.gitignore` rules pointed at a folder that no longer exists** (2026-08-28) — `.gitignore`.
  `Packages/Sydney/CBuilder/Win64/` and `Packages/Sydney/cpp/` were left behind when the pre-D13 package folders were removed. The generic `Packages/*/cpp/` rule added the same day still covers the one remaining case, `11AndAbove`. Checked afterwards that no tracked file became ignored and that `37.0/` and `Packages/11AndAbove/cpp/` are still excluded by this repository's own file rather than a global one.

- **The fork's stated scope said "Win64 only", which is out of date** (2026-08-28) — `readme.md`, `CHANGELOG.md`, `CLAUDE.md`.
  The global rule now covers **both Win32 and Win64** (Ian), superseding the earlier Win64-only position; packages build all four modes and the demos are verified on both platforms. All three documents said otherwise in their opening scope line, which is the first thing a reader sees.
  Corrected in place rather than reconciled: an intermediate edit had tried to present "built for both" and "Win64 only" as two true statements about different things, which would have preserved a stale rule as though it were a deliberate distinction. `CLAUDE.md` now records that the phrase is superseded, so finding it in an old note reads as staleness rather than nuance.

- **The install instructions sent C++Builder users to an `hpp` directory this fork does not produce** (2026-08-28) — `readme.md`.
  Step 3 of *Installation* is upstream text telling the reader to add `source\hpp\Win32\Release` to the IDE's system include path. Since `DCC_CBuilderOutput` became `None` no `.hpp` is emitted, so that directory does not exist. The existing note under **Package names** explains why, but it is three sections away from the step someone is actually following, so a one-line pointer now sits with the step itself.

- **Eight of the twelve demos could not build for Win64** (2026-08-28) — `Demos/EditAppDemos/frmEditor.pas`, `Demos/Folding/uFoldingDemoForm.pas`, `Demos/HighlighterDemo/SynHighlighterSample.pas`, `Demos/PrintDemo/DTestPrintPreview.pas`, `Demos/SearchReplaceDemo/SearchReplaceMain.pas`, `Demos/SimpleIDEDemo/SimpleIdeMain.pas`.
  All twelve built for Win32, which is why this had gone unnoticed. The cause is upstream's own `TSynNativeInt` in `Source/SynFunc.pas`, which is `Int32` below `COMPILERVERSION 36` and `NativeInt` from Delphi 12 on. On Win32 `NativeInt` *is* `Integer`, so nothing shows; on Win64 it is 64-bit and every demo event handler still declaring `Integer` stops matching the library's event type.
  In most cases the *interface* declarations had already been updated to `NativeInt` and only the implementations still said `Integer` — `E2037 Declaration ... differs from previous declaration`, followed by a cascade of undeclared-identifier errors that hid how simple the real fault was. `uFoldingDemoForm` and `SynHighlighterSample` had both halves wrong.
  `frmEditor.pas` also hard-cast `TBufferCoord` to `TPoint`. That works while `TBufferCoord` is two 4-byte fields, and fails with `E2089 Invalid typecast` once they are 8-byte, so it now copies the fields across.
  `NativeInt` was used rather than `TSynNativeInt` because on Delphi 13 they are the same type and it needs no new `uses` entry; `SimpleIdeMain.pas` already used `NativeInt` in places, so it matches what was there.
  Verified: all 12 demos build for **Win32 and Win64**, and the two packages still build in all four modes.

- **Build output is now excluded by this repository's own `.gitignore`** (2026-08-28) — `.gitignore`.
  `37.0/`, `Packages/*/Delphi/Win32|Win64/` and `Packages/*/cpp/` were being ignored only by a machine-level `core.excludesFile`. The existing rules cover `.dcu`, `.bpl` and `.dcp`, but not the `.dfm` and `.res` the compiler copies into those folders — 36 such files under `37.0/` alone — so a clone on a machine without that global file would have committed build output. Checked afterwards that no currently tracked file became ignored, and that the deliberate `!Packages/11AndAbove/Delphi/*.res` exception still holds.

- **C++Builder output turned off** (2026-08-26). `DCC_CBuilderOutput` was `All`, so every build emitted `.hpp` / `.bpi` / `.a` / `.obj` files for a compiler that is **never in scope here** (standing rule: "I dont use C++ at all"). Across the estate that was 616 files and 90 MB of output nobody consumes, regenerated on every build; `gllSynEdit` alone accounted for 560. Now `None`. The `DCC_HppOutput` / `DCC_BpiOutput` / `DCC_ObjOutput` properties are left in place deliberately - they only say *where* such files would go, so with generation off they are inert, and removing them would enlarge the diff without changing behaviour. Verified: the affected packages rebuilt clean in every enabled mode, emitted no C++ artefacts, and rebuilt clean again after the existing ones were deleted (so nothing was load-bearing).

- **`readme.md` now states that this fork is Delphi-only** (2026-08-26) — `readme.md`. The inherited TurboPack text lists `SynEditCR.bpl` / `SynEditCD.bpl` among the package names as though they were part of the release. They are not built here: only `SynEditDR` and `SynEditDD` under `Packages\11AndAbove\Delphi` are, and `Packages\11AndAbove\CBuilder\` is upstream content this fork carries but never compiles. A note under that list says so, and records that the two Delphi packages now also have `DCC_CBuilderOutput=None` — a reader who genuinely needed C++ interop would otherwise find the `.hpp`/`.bpi` files simply absent with nothing to explain why.





- Debug and Release package output no longer collide (2026-08-24)
  **Why:** RAD Studio defaults `DCC_BplOutput` to `$(BDSCOMMONDIR)\Bpl\$(Platform)` and `DCC_DcpOutput` to `\Dcp\$(Platform)`, neither carrying `$(Config)`, so a Debug build silently replaced the installed Release package.
  Release still writes to the shared `Bpl`/`Dcp` folders - that is what is on `PATH`, and it is where dependent packages resolve their `requires` from - while Debug is diverted to a `$(Config)` subfolder. Separating Release as well breaks package loading, so only Debug moves.

- Cherry-picked upstream `92cb01b`, `012e45b` and `55331b2` (2026-08-12/16, upstream PR #359 by
  Carlo Sirna) — `Source\DesignTimeEditors\SynDelphiIDEImporter.pas`. `TSynIDEImportEditor`
  descended from `TComponentEditor`, whose inherited `Edit` executes the **first verb**, so a plain
  double click on a `TSynEdit` or `TSynDelphiSyn` in the form designer silently ran "Import IDE
  Settings" — overwriting the component's font, colours, gutter, selection, tab settings and
  highlighter attributes with the IDE's, with no prompt and no undo. The class now descends from
  `TDefaultEditor`, whose `Edit` creates or jumps to the default event handler (the behaviour a
  double click is expected to have), and the verb itself gained a `mtWarning` confirmation
  defaulting to **No** that names what will be overwritten. `System.UITypes` was added to the uses
  clause for `MessageDlg`'s result and button constants. The unit ships in `SynEditDD.dpk`, so this
  fork was exposed. `SynEditDD` builds clean in Win64 Debug and Release. (2026-08-22)

### Changed

- Converted to the suite's Lib-DCU model (2026-08-13) — `Packages\11AndAbove\Delphi\SynEditDR.dproj`,
  `Packages\11AndAbove\Delphi\SynEditDD.dproj`. DCU output moved from `.\$(Platform)\$(Config)`
  (inside the Packages folder) to the house convention `37.0\$(Platform)\$(Config)` at the repo
  root, and a post-build event on the runtime package copies `Source\*.dfm`/`*.res` beside the
  DCUs (`{$R}` resources bind at link time). The IDE Library Path now serves
  `37.0\Win64\Release` (Debug DCUs on the Debug DCU Path; `Source` + `Source\Highlighters`
  on the Browsing Path) instead of compiling SynEdit from source into every consuming project.

### Added

- `SynHighlighterWebStencils.pas` was on disk but wired into neither package — added to the
  runtime package (contains clause + DCC reference), matching the `SynHighlighterWebIDL`
  precedent: no `SynEditReg` palette registration, the unit self-registers as a placeable
  highlighter in its initialization section. The unit did not compile against the current
  `TSynCustomHighlighter` API (likely why upstream never packaged it) and needed aligning:
  `GetTokenKind`/`SetLine` signatures `Integer` → `TSynNativeInt`, `SynFunc` added to the
  uses clause, and `IsKeyword` marked `override` (it silently hid the base virtual, W1010).
  (2026-08-06) — `Packages/11AndAbove/Delphi/SynEditDR.dpk`,
  `Packages/11AndAbove/Delphi/SynEditDR.dproj`, `Source/Highlighters/SynHighlighterWebStencils.pas`

### Fixed

- On Win64 the Progress highlighter's `GetRange` returned 4 bytes of uninitialised stack in
  the upper half of the range pointer (stack-local variant record with only the low dword's
  Word fields written), defeating `ScanFrom`'s range-equality early-exit so edits could
  rescan to end of file; the pointer is now zeroed first. Same fix applied to the three
  dormant clones behind the disabled `SYN_HEREDOC` define. (2026-08-06) —
  `Source/Highlighters/SynHighlighterProgress.pas`, `Source/Highlighters/SynHighlighterPHP.pas`,
  `Source/Highlighters/SynHighlighterRuby.pas`, `Source/Highlighters/SynHighlighterUNIXShellScript.pas`
- `TSynEditPrint.PrintRange` leaked one screen HDC per print job: the `GetDC(0)` handle
  passed to `BindDC` was never released; it is now captured and released in the `finally`.
  (2026-08-06) — `Source/SynEditPrint.pas`
- `TSynMacroRecorder.LoadFromFile` added a macro event to `fEvents` before initialising it;
  a failed `InitEventParameters` freed the event but left the dangling pointer in the list
  (use-after-free on later playback/clear). Init now precedes the add. (2026-08-06) —
  `Source/SynMacroRecorder.pas`
- `TSynSpellCheck.Destroy` removed free notifications but left each surviving editor's
  `TSpellCheckPlugin` alive with a dangling back-reference to the destroyed component
  (use-after-free on the next keystroke); it now detaches via `RemoveEditor`, which also
  frees the plugin. (2026-08-06) — `Source/SynSpellCheck.pas`
- The two Delphi 13 package `.res` files were untracked, swallowed by the blanket `*.res`
  ignore rule, so a fresh clone could not build the packages as committed; a negation
  pattern now tracks them. (2026-08-06) — `.gitignore`,
  `Packages/11AndAbove/Delphi/SynEditDR.res`, `Packages/11AndAbove/Delphi/SynEditDD.res`

### Changed

- Replaced the readme's stale "Fork Reason" section (a leftover note from the upstream
  WebStencils contributor's fork, which misdescribed this repository) with the gllSynEdit
  fork identity: D13+/Win64-only scope, CHANGELOG-as-fork-delta, merge-from-upstream policy.
  (2026-08-06) — `readme.md`

### Removed

- Stale XE6-era `SynEdit_RXE6` package reference from the designtime project's Win32
  `DCC_UsePackage` (dead package name; would break any future Win32 build). (2026-08-06) —
  `Packages/11AndAbove/Delphi/SynEditDD.dproj`

- Fork established from a fresh upstream clone at `95da62f` (2026-07-23), replacing the
  year-old `D:\SynEdit` working copy whose 217-commits-behind state and uncommitted local
  package edits made a clean upgrade impossible. This tree supersedes both that copy and the
  dead `pyscripter/SynEdit-2` clone (upstream abandoned 2020, superseded by TurboPack).
  (2026-08-06)

### Changed

- Default platform Win32 → Win64 in the Delphi 13 package projects. The packages remain
  `$(Auto)`-suffixed, producing `SynEditDR370.bpl` / `SynEditDD370.bpl`. Both verified
  building clean Win64 Debug + Release (Release last — shared BPL output); the 29 W1072
  warnings in upstream's `Source\Highlighters` units are upstream's and are left alone.
  (2026-08-06) — `Packages/11AndAbove/Delphi/SynEditDR.dproj`,
  `Packages/11AndAbove/Delphi/SynEditDD.dproj`
  **Why:** the suite is Win64-only and the design package must load in the 64-bit IDE;
  Win32 output would land in the root `Bpl`/`Dcp` folders where it shadows other trees.
