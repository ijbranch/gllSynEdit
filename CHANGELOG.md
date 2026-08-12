# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

GITLAK fork of TurboPack SynEdit (upstream `https://github.com/TurboPack/SynEdit`).
Scope: **Delphi 13+ / Win64 only**, installed into the 64-bit RAD Studio IDE. Upstream
content is unmodified except where entries below say otherwise, so the fork delta stays
visible.

## [Unreleased]

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
