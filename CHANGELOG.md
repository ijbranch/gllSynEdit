# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

GITLAK fork of TurboPack SynEdit (upstream `https://github.com/TurboPack/SynEdit`).
Scope: **Delphi 13+ / Win64 only**, installed into the 64-bit RAD Studio IDE. Upstream
content is unmodified except where entries below say otherwise, so the fork delta stays
visible.

## [In-Service]

> Libraries and packages are continuously deployed: changes below are live as soon as the package is rebuilt and installed - there is no separate release step, so no `[Unreleased]` backlog. Tagged version snapshots are listed beneath.

### Fixed- **C++Builder output turned off** (2026-08-26). `DCC_CBuilderOutput` was `All`, so every build emitted `.hpp` / `.bpi` / `.a` / `.obj` files for a compiler that is **never in scope here** (standing rule: "I dont use C++ at all"). Across the estate that was 616 files and 90 MB of output nobody consumes, regenerated on every build; `gllSynEdit` alone accounted for 560. Now `None`. The `DCC_HppOutput` / `DCC_BpiOutput` / `DCC_ObjOutput` properties are left in place deliberately - they only say *where* such files would go, so with generation off they are inert, and removing them would enlarge the diff without changing behaviour. Verified: the affected packages rebuilt clean in every enabled mode, emitted no C++ artefacts, and rebuilt clean again after the existing ones were deleted (so nothing was load-bearing).- **`readme.md` now states that this fork is Delphi-only** (2026-08-26) — `readme.md`. The inherited TurboPack text lists `SynEditCR.bpl` / `SynEditCD.bpl` among the package names as though they were part of the release. They are not built here: only `SynEditDR` and `SynEditDD` under `Packages\11AndAbove\Delphi` are, and `Packages\11AndAbove\CBuilder\` is upstream content this fork carries but never compiles. A note under that list says so, and records that the two Delphi packages now also have `DCC_CBuilderOutput=None` — a reader who genuinely needed C++ interop would otherwise find the `.hpp`/`.bpi` files simply absent with nothing to explain why.





- Debug and Release package output no longer collide (2026-08-24)
  **Why:** RAD Studio defaults `DCC_BplOutput` to `$(BDSCOMMONDIR)\Bpl\$(Platform)` and `DCC_DcpOutput` to `\Dcp\$(Platform)`, neither carrying `$(Config)`, so a Debug build silently replaced the installed Release package.
  Release still writes to the shared `Bpl`/`Dcp` folders - that is what is on `PATH`, and it is where dependent packages resolve their `requires` from - while Debug is diverted to a `$(Config)` subfolder. Separating Release as well breaks package loading, so only Debug moves.

### Fixed

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
