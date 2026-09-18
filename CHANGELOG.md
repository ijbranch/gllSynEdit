# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

GITLAK fork of TurboPack SynEdit (upstream `https://github.com/TurboPack/SynEdit`).
Scope: **Delphi 13+**, built for Win32 and Win64, installed into the 64-bit RAD Studio IDE. Upstream
content is unmodified except where entries below say otherwise, so the fork delta stays
visible.

## [Unreleased]

### Reviewed and deliberately NOT taken from upstream, so they are not re-derived later

- **Upstream swept 2026-09-18: `11Alexandria` and `multicursor` reviewed, nothing taken.**
  Neither branch had a prior record here.
  - `30cd5cc` (`11Alexandria`) - DECLINED by its own text: the commit edits that branch's README
    to say it "is for legacy 11Alexandria support only and doesn't have the latest updates". One
    commit since a 2023 merge-base, so "1 behind" is a dead branch, not a backlog.
  - `fb9e365` (`multicursor`) - DECLINED, superseded. A 2020 experimental spike
    (`Source/SynEditMultiCaret.pas`, 1,180 new lines) on a single-commit branch, abandoned
    upstream and replaced by the `TSynSelection`/`TSynSelections` design **this fork already
    carries** (`ExecuteMultiCaretCommand`, `CommandInfo.StoreMultiCaret`, plus
    `Doc/Multi-caret.md`). It rewrites 430 lines of `SynEdit.pas` from a 2020 base, so it could
    not merge cleanly and would not build - it would drop a dead parallel implementation into a
    fork that has the finished one.
  **Condition to reopen:** only if upstream revives either branch with post-2023 work. This
  triage covered those two branches only; `master`, `pyscripter`, `DelphiFeatures` and `GDI` are
  worth checking on a future sweep.

### Added

- **`build.cmd` — one command that builds and tests everything, in the order that works**
  (2026-09-14). `build.cmd` runs the eight package builds, the 24 demo builds and the test suite
  on both platforms and exits non-zero if anything fails; `build.cmd packages` and
  `build.cmd tests` do just those. It builds the runtime package **before** the design-time one
  (the reverse fails `E2225` on a stale `.dcp`) and reverts the `SynEditDD.res` that MSBuild
  rewrites, so a build does not show up as a source change.
  **Why:** there was no way for a contributor to self-check before opening a PR, and the ordering
  and the `.res` quirk are exactly the things a newcomer gets wrong.

- **A DUnitX test suite — the first automated tests this library has ever had** (2026-09-14) —
  `Tests/SynEditTests.dpr`, `Tests/SynEditTests.dproj`, `Tests/TestHighlighterContract.pas`,
  `Tests/TestTextBuffer.pas`, `.gitignore`.
  `TestHighlighterContract` is data-driven over `GetPlaceableHighlighters`, so it asserts the
  scanning contract against **all 83 registered highlighters** with no per-language knowledge:
  construction is clean, `Next` always advances or reaches end of line, `GetRange` round-trips
  through `SetRange`, and each highlighter scans its own `SampleSource` identically whether the
  range is restored per line or not. 20 probe lines, each of which has broken a highlighter in
  practice. `TestTextBuffer` covers the `TSynEditStringList` defects fixed below.
  **It earned its place immediately**: on its first run it found a non-advancing `Next` in
  `TSynXMLSyn` that no build diagnoses — see the `TSynCustomHighlighter.Next` entry below.
  7/7 pass, Win32 and Win64.
  **Why:** 132,000 lines, 84 highlighters and no test of any kind; the defect class that hangs the
  editor is invisible to the compiler.
  **All three `TestTextBuffer` tests are mutation-proved**: reverting each of the three fixes
  independently turns exactly one test — the right one — red. The two double-release tests
  originally asserted only that the held line was still *readable*, which passed under mutation
  because reading freed memory does not reliably fault. They now assert the **reference-count
  delta** across `Clear`, which must be exactly 1: the list holds one reference, so it may release
  one. Measured on this tree, the drop is 1 with the fix and 2 without. That is a deterministic
  observable and needs no debug memory manager.

### Changed

- **All 34 `W1072` narrowing warnings, all 7 `H2269` visibility hints and the one `W1050`
  eliminated** (2026-09-14) — 20 files. The runtime package now compiles **clean under
  `dcc64 -H -W`**, from 32 warnings and 7 hints at the start. The `W1072`s were `Run` (a
  `TSynNativeInt`) assigned to `Integer` locals, parameters and fields; each receiving declaration
  was widened rather than cast, because that is the same shape as the DWS defect above — which was
  introduced by a warning-cleanup commit. The `H2269`s were seven `TSynWebStencilsSyn` overrides
  declared with lower visibility than the base, which made them unreachable through a
  `TSynCustomHighlighter` reference.
- Raises carrying hardcoded English literals moved to `resourcestring`s and to `ESynError`
  (2026-09-14) — `Source/SynEdit.pas`, `SynEditScrollBars.pas`, `SynEditSearch.pas`,
  `SynEditWordWrap.pas`, `SynEditPrintMarginsDialog.pas`, `SynCompletionProposal.pas`,
  `SynMacroRecorder.pas`, `SynEditStrConst.pas`. The base `Exception` class cannot be filtered on
  by callers. `SYNS_NoSearchEngineError` already existed and is reused. The print-margins dialog
  also now parses all ten fields into locals before committing any of them — a bad value in a late
  field used to leave the margins half-old and half-new — and catches only `EConvertError`.
- `SYNS_FilterYAML` now lists `*.yml` alongside `*.yaml` (2026-09-14) — `Source/SynEditStrConst.pas`.

- Documentation brought level with this batch (2026-09-14) — `readme.md`, `CLAUDE.md`.
  `readme.md` gains a **Building and testing** section (what `build.cmd` does, why the package
  order matters, what the highlighter contract asserts and why no build catches a breach of it)
  and a **Documentation** section linking `Doc/CodeFolding.md` and `Doc/Multi-caret.md`, which
  existed but were unreachable from the readme. The install steps now name
  `Source\DesignTimeEditors` and say the design package must be installed from the 64-bit IDE.
  `CLAUDE.md` corrects two claims this batch invalidated - it named `SynEditJedi.inc` as a file to
  leave alone, and quoted the `{$IF COMPILERVERSION < 36}` guard around `TSynNativeInt` that no
  longer exists - and records that `SynHighlighterDelphi.pas` is now the only file a mechanical
  directive pass must refuse, with the reason (its keyword array contains the literals
  `'initialization'` and `'finalization'`).
- The indent-guide stroke width is documented as deliberate (2026-09-14) — `Source/SynEdit.pas`.
  The `Round(FCurrentPPI / 96)` next to a commented-out fractional variant looks like a DPI
  rounding defect and is not: the block runs under `D2D1_ANTIALIAS_MODE_ALIASED`, where Direct2D
  snaps strokes to whole pixels anyway. A comment now says so. **This corrects the review, which
  had listed it as a defect.**


- Documentation brought level with the D13 / Win32+Win64 / no-C++Builder / no-non-Windows
  state (2026-09-10) — `CLAUDE.md`, `New.md`, `readme.md`
  Stale supported-version ranges, per-IDE folder paths, C++Builder offers, non-Windows
  platform claims and Win64-only/Win32-only statements corrected against the current tree.
  Dated reports and upstream-authored prose were left as history.

- Non-Windows conditional compilation resolved away in 1 source file — 7 constructs (2026-09-10)
  `{$IFDEF POSIX|LINUX|ANDROID|IOS|MACOS|OSX|UNIX}` blocks were dropped and
  `{$IFDEF MSWINDOWS|WINDOWS}` blocks collapsed to their Windows branch, keeping exactly
  what a Win32/Win64 compile keeps. Conditions that are not constant across both our
  platforms (`WIN32`, `WIN64`, `CPUX64`, compound `{$IF}`) were left untouched, as were
  files whose directive nesting is unbalanced by design (JEDI-style includes).
  **Why:** the dead branches could never be reached here and only misled the reader.

- Project platforms normalised to Win32 + Win64 only in 6 `.dproj` files (2026-09-10)
  Non-Windows targets (`Android`, `Android64`, `iOS*`, `OSX*`, `Linux64`) and the
  `Win64x` / `WinARM64EC` variants were removed together with their `Base_<Plat>` and
  `Cfg_N_<Plat>` property groups, `<Deployment>` platform nodes and `<ProjectRoot>`
  entries; a deactivated `Win32` or `Win64` was switched on.
  **Why:** standing suite rule — every gll* project is Delphi 13, Win32 + Win64, nothing
  else, so the four-mode package sweep is always possible.

- Codeberg is retired; every repository URL points at GitHub again (2026-09-05).
  **Why:** hosting consolidated back on GitHub. `origin` is the GitHub URL, the stale
  `codeberg` remote has been removed from the working checkout, and the documentation that
  says where to clone from was updated to match. The Codeberg entry below is superseded;
  its URLs are left as written because rewriting them would falsify the record.

- Repository moved to the `GITLAK-forks` Codeberg organisation: `origin` is now `https://codeberg.org/GITLAK-forks/gllSynEdit.git`. **Why:** the `GITLAK` account had reached Codeberg's hard limit of 100 repositories, and an organisation carries its own allowance (2026-09-03)
  **Superseded 2026-09-05:** Codeberg is no longer used; see the entry above.

### Removed

- **`Source/SynEditJedi.inc` deleted — 2,160 lines** (2026-09-14) — `Source/SynEdit.inc`.
  It detected compilers from Delphi 1 (`VER80`) to Delphi 13 (`VER370`) across 646 version-bearing
  lines and 502 defines, and this library used **none** of the symbols it produced. Proved by
  substitution rather than asserted: the whole runtime package (135 units, 221,548 lines) compiles
  clean against an empty stub of it. It also carried the only deliberately unbalanced directive
  nesting in the tree, which was a standing obstacle to any mechanical pass over the sources.
- **78 dead `COMPILERVERSION` conditionals resolved away** (2026-09-14) — `Source/SynDWrite.pas`,
  `SynEdit.pas`, `SynEditMiscClasses.pas`, `SynEditPrintPreview.pas`, `SynEditTextBuffer.pas`,
  `SynEditUndo.pas`, `SynEditWordWrap.pas`, `SynFunc.pas`, `SynUnicode.pas`,
  `Highlighters/SynHighlighterDelphi.pas`.
  Delphi 13 is this fork's floor, so guards for XE8, Seattle, Berlin, Tokyo, Rio, Sydney,
  Alexandria and Athens could never be taken. Only the four forward-looking
  `{$IF COMPILERVERSION >= 38}` deprecation markers remain. Among the casualties:
  `TSynInt64 = Integer`, a type whose name said Int64 and which was 32-bit on the older half of the
  old supported range.
  **Done with a preprocessor-accurate resolver, not a regex** — it tracks every construct-opening
  directive including `{$IFOPT}`, refuses any file whose net directive depth is not zero, and
  re-checks balance after rewriting. `SynHighlighterDelphi.pas` was correctly refused by it (its
  directive nesting is unbalanced by design) and its three sites were done by hand.
  **Why it matters that this was careful:** a first attempt with a regex silently unbalanced
  `SynEditTextBuffer.pas` and `SynEditWordWrap.pas`, and a later `s.index('initialization')`
  matched the literal inside the Delphi highlighter's keyword array and truncated 600 lines. Both
  were caught by a balance check and a line count, and both files were restored and redone by hand.



- C++Builder content removed — 5 files (2026-09-10)
  `.cbproj` projects and their `.cpp`/`.h`/`.bpr` companions, the C++Builder project
  groups and the generated `.hpp`. **Why:** C++Builder is not used here and never has
  been; the files were never built, so they were pure noise in every audit and search.
  The `DCC_HppOutput`/`DCC_BpiOutput`/`DCC_ObjOutput` properties in `SynEditDD.dproj` and
  `SynEditDR.dproj` went too, with the `Packages/11AndAbove/cpp` tree MSBuild kept recreating.
  Kept deliberately: `Demos/Folding/demo.cpp` is syntax-highlighting SAMPLE DATA beside
  `demo.js` and `demo.py`, not C++Builder code.

### Fixed

Upstream defects, found by review and fixed here. **The full write-up was submitted to
TurboPack on 2026-09-14**, so some of these may return through a future
`git merge upstream/master` - expect conflicts in these files and resolve in favour of
whichever version is correct rather than assuming ours is the change.

**Memory safety and lifetime**

- `TSynDWSSyn` wrote and then **called** outside its 389-entry method-pointer table (2026-09-14) —
  `Source/Highlighters/SynHighlighterDWS.pas`.
  Upstream commit `9874fe1` ("Removed some warnings") changed `HashKey` from `Cardinal` to
  `NativeInt` and dropped a `ToUInt32`; the accumulator wraps into the sign bit, Delphi's `mod`
  truncates toward zero, and the one-sided `if Key <= High(...)` guard admits every negative
  index. Re-derived numerically: `'abstract'` — the first keyword hashed — lands at **-260**, and
  26 of the 95 keywords hash negative on Win64. It fires in the constructor, before any file is
  opened. Unsigned arithmetic restored throughout, plus a bounds check in `SetIdentFunc`, whose
  parameter is now `Cardinal` to match (a signed parameter also cost a W1071 on every Win32 call).
- `TSynEditStringList.DeleteNative`/`DeleteLines` left an untracked string alias in the vacated
  slot (2026-09-14) — `Source/SynEditTextBuffer.pas`.
  The `System.Move` shifted records down without clearing the tail, so one managed string was
  named by two array elements but counted once; `SetLength` (from `SetCapacityNative`, which
  `Clear` and `Destroy` both call) then released it twice. Cleared raw with `FillChar` —
  `Finalize` would release the reference the moved-down copy now owns.
- `TSynEditStringList.SetCapacityNative` built an `EListError` and never raised it (2026-09-14) —
  `Source/SynEditTextBuffer.pas`. The guard did nothing, the exception object leaked, and
  `SetLength` truncated the array below `FCount`.
- `TSynDWrite.ResetRenderTarget` dereferenced its lazily-created brush cache (2026-09-14) —
  `Source/SynDWrite.pas`. `SynEditPrint` calls it as its *first* DirectWrite touch, so a print
  preview shown before any editor had painted took an access violation.
- `TSynSpellCheck.Destroy` cleared the class-wide `GlobalInstance` even when the instance never
  owned it (2026-09-14) — `Source/SynSpellCheck.pas`. A rejected second construction ran the
  destructor on the half-built instance and destroyed the singleton guard, after which a third
  construction succeeded and two live instances existed.
- `THeaderFooter.Delete` removed the item from a plain `TList` without freeing it (2026-09-14) —
  `Source/SynEditPrintHeaderFooter.pas`. Leaked a GDI-backed `TFont` on every call.
- `TSynMacroRecorder.LoadFromStreamEx` leaked the whole existing macro when `aClear` was False
  (2026-09-14) — `Source/SynMacroRecorder.pas`. It also discarded the macro it was meant to
  append to.
- `TSynEditPlugin.Create(nil)` faulted on the nil owner it had just guarded against (2026-09-14) —
  `Source/SynEdit.pas`.
- `TCustomSynEdit.CreateWnd` leaked its `TSynDropTarget` whenever `RegisterDragDrop` failed
  (2026-09-14) — `Source/SynEdit.pas`, `Source/SynEditStrConst.pas`. The target is a
  `TInterfacedObject` held in an *object* variable, so registration was what gave it an owner;
  it is now held as `IDropTarget` and the HRESULT is checked.

**Data loss**

- `CutToClipboard` deleted a selection that was never copied (2026-09-14) — `Source/SynEdit.pas`.
  `OleSetClipboard` fails with `CLIPBRD_E_CANT_OPEN` whenever another process has the clipboard
  open — clipboard managers, RDP and VM clients, Office all hold it briefly — and the HRESULT was
  discarded. New `TCustomSynEdit.TryCopyToClipboard: Boolean`; `CutToClipboard` deletes only on
  success. `CopyToClipboard` keeps its signature.
- `TSynCustomExporter.SetClipboardText` emptied the clipboard before it knew the replacement could
  be built (2026-09-14) — `Source/SynEditExport.pas`. A failed allocation destroyed whatever the
  user had. `Clipboard.Clear` moved after the successful `GlobalLock`, and both clipboard routines
  now free only the block they still own — the old `except GlobalFree; OutOfMemoryError; end` could
  free a block the clipboard had already taken, and reported every failure as out-of-memory.
- `IsAnsiOnly` read an uninitialised `BOOL` and is broken outright on a UTF-8 ACP (2026-09-14) —
  `Source/SynUnicode.pas`. `WideCharToMultiByte` fails with `ERROR_INVALID_PARAMETER` when
  `lpUsedDefaultChar` is non-nil and the code page is `CP_UTF8`/`CP_UTF7`, and on Windows 10 1803+
  with "Use Unicode UTF-8 for worldwide language support" enabled that is exactly `GetACP()`. Its
  only consumer is the "you will lose characters saving as ANSI" warning, which therefore fired at
  random. Same treatment for `IsWideCharMappableToAnsi`.
- Drag-and-drop deleted the selection with no drop (2026-09-14) — `Source/SynEdit.pas`.
  `dwEffect` was never initialised and `DoDragDrop` writes it only on `DRAGDROP_S_DROP`, so a stale
  `DROPEFFECT_MOVE` on the stack — or any failure HRESULT, or an exception out of the drag loop —
  destroyed the selection.

**Out-of-bounds reads and writes**

- `WM_IME_COMPOSITION` used a negative `ImmGetCompositionStringW` result as an allocation size
  (2026-09-14) — `Source/SynEdit.pas`. `IMM_ERROR_NODATA` (-1) and `IMM_ERROR_GENERAL` (-2) gave
  `GetMem(PW, 0)` then `PW[-1] := #0`, and `DWORD(ImeCount)` handed the IME `$FFFFFFFF` as a buffer
  length. `ImmGetContext` was also unchecked, although `WMImeNotify` 27 lines below does check it.
- `SafeArrayPutElement` was passed one level of indirection too few, twice (2026-09-14) —
  `Source/SynAccessibility.pas`. `pv` is an untyped `const`, so `Pointer(TextRange)^` passed the
  interface pointer *value* as the address and OleAut32 took the object's vtable pointer as the
  interface. Any UI Automation client calling `GetSelection`/`GetVisibleRanges` — Narrator
  included — called through a bogus vtable. The unit's own correct idiom is 490 lines further down.
- `TSynHighlighterAttributes.LoadFromBorlandRegistry` indexed a 16-entry palette with an unclamped
  registry value, behind two bare `except end` (2026-09-14) — `Source/SynEditHighlighter.pas`.
  With range checks off — the stock Release setting — `Pal16[255]` read a kilobyte past the
  constant and assigned it as a `TColor`. The attribute was also left half-updated while the
  function reported "nothing was loaded". Index clamped, parsing made atomic, catch narrowed to
  `ERegistryException`.
- `WM_GETTEXT` with `wParam = 0` produced `$FFFFFFFF` as the copy length (2026-09-14) —
  `Source/SynEdit.pas`. `TextMax` is an unsigned pointer-sized `WPARAM`, so `TextMax - 1` wrapped.
- `TSynCssSyn.ExclamProc` read nine characters past the line terminator (2026-09-14) —
  `Source/Highlighters/SynHighlighterCss.pas`.
- Out-of-bounds `fLine[Run - 1]` reads guarded in `SynHighlighterHtml.pas`, `SynHighlighterXML.pas`
  (two sites), `SynHighlighterSQL.pas` and `SynHighlighterPerl.pas` (2026-09-14). Note
  `SynHighlighterPerl.SymbolProc` already guarded the identical test, which is what showed the
  omission was accidental.

**The editor could hang, and now cannot**

- `TSynCustomHighlighter.Next` is now the library's single scanner-progress guard (2026-09-14) —
  `Source/SynEditHighlighter.pas`. Every scanning loop is `while not GetEol do Next`, and nothing
  required `Next` to consume anything, so a token procedure that returned without advancing `Run`
  spun for ever inside a paint handler with the message loop blocked. All 83 highlighters end
  their `Next` with `inherited`, so the base class is the one place that covers every one of them.
  It asserts (naming the highlighter and the column) and forces progress, degrading a scanner
  defect to wrong colours on one line instead of an unkillable freeze. This is the shape of
  upstream issue **#261**, "CSS highlighter locks up application".
  **Two things implementation changed about the original design:**
  1. The guard compares `Run` against **`fTokenPos`**, not against the `fOldRun` field. `fOldRun`
     is a field, so the HTML/PHP/XML highlighters' re-entrant `Next` call updated it and made the
     test trivially true on the way out — a false positive *and* a spurious `Inc(Run)`. The new
     test caught this within minutes of first running.
  2. The three hand-rolled `if (fOldRun = Run) and not GetEol then Next;` retries in those
     highlighters were **kept, not removed as first proposed**. They are load-bearing:
     `TSynXMLSyn.QAttributeValueProc` deliberately emits a zero-length token at an `&`, flipping to
     `rsQuoteEntityRef` without consuming anything, and relies on the retry to re-dispatch into the
     new range. Removing them made `<root version="&test;">` stall. Comments now say so.
- `TSynSQLSyn`'s `rsConsoleOutput` arm could not reach end of line (2026-09-14) —
  `Source/Highlighters/SynHighlighterSQL.pas`. Unreachable today, but a hang built into dead code.
- `TSynTypeScriptSyn` gained ECMAScript private names (`#count`) via a `PrivateNameProc` that
  consumes the `#` **first** (2026-09-14) — `Source/Highlighters/SynHighlighterTypeScript.pas`.
  Adding `'#'` to the `IdentProc` branch instead would have been a hang, because `IsIdentChar`
  rejects `#` and the scan loop would have consumed nothing.

**Wrong highlighting**

- `TSynDelphiSyn` turned the rest of a unit into a string on `''''` (2026-09-14) —
  `Source/Highlighters/SynHighlighterDelphi.pas`. The triple-quote test ran before the
  "already inside a multi-line string" test and did not check the fourth character, so the
  commonest literal in Pascal — the one holding a single apostrophe — armed `rsMultilineString`
  and never left it. A `'''` terminator in column 1 had the same effect. Also: `Integer`,
  `string`, `Boolean` and the rest now paint as data types via a new sorted `DelphiTypes` list
  (`fTypeAttri` was published but unreachable), `'widestring'` added to the keyword list, and the
  class registers itself with `RegisterPlaceableHighlighter` as every sibling does.
- `TSynPasSyn.KeyWords[125]` was `'string'` where the hash table expects `'widestring'`
  (2026-09-14) — `Source/Highlighters/SynHighlighterPas.pas`. `'string'` appeared twice and
  `'widestring'` not at all, so `WideString` was the only standard string type not coloured as a
  type. Verified by re-running the unit's own hash over all 132 keywords: 0 mismatches after.
- Cross-line scanner state that `GetRange` did not carry, now packed into the range pointer
  (2026-09-14) — CSS (`fCommentRange`, `fParameterRange`; neither was initialised either, and
  `rsComment` is ordinal 0), Python (`fStringStarter`), DWS (`fCommentClose`), WebStencils
  (`rsComment` was dropped by `SetLine`, so `@* … *@` could not span lines). `TSynSQLSyn` already
  did this correctly for its Oracle q-quote delimiter and was the model.
- `TSynHTMLSyn` could not recognise `!doctype` (2026-09-14) —
  `Source/Highlighters/SynHighlighterHtml.pas`. `HashKey` had stopped consuming `'!'` but
  `KeyIndices` was generated as if it did. Verified numerically: 255 of 257 keywords round-trip,
  and the two that do not are `!doctype` and `/!doctype`; with `'!'` restored, 0 mismatches.
- JScript strings ending in an escaped backslash never terminated (2026-09-14) —
  `Source/Highlighters/SynHighlighterJScript.pas`. `var p = "C:\\"; var y = 2;` swallowed the rest
  of the line. Also `SlashProc`'s `and`/`or` precedence bug, and `'NaN'` moved to element 0 of a
  case-sensitive ASCII-ordered array that a binary search could never otherwise find it in.
- A bare `<` in Markdown prose turned the rest of the document into HTML attribute names
  (2026-09-14) — `Source/Highlighters/SynHighlighterMarkdown.pas`. Also: a closing code fence with
  trailing whitespace never closed the block; `HtmlAttrNametAttri` renamed (stray `t` — note this
  is a **breaking DFM property rename**); whitespace now emits `tkSpace` so `SpaceAttri` has an
  effect; and a default filter added (it was the only fixed-language highlighter without one).
- Every Perl token starting with `q` was emitted as a one-character identifier (2026-09-14) —
  `Source/Highlighters/SynHighlighterPerl.pas`. `quotemeta` scanned as `q` + `uotemeta`, so the
  keyword never matched; `qw()`, `qx`, `qr`, `qq{}` likewise. The replacement handles the whole
  family with arbitrary delimiters. Backtick commands and `\'` in single-quoted strings also fixed.
- Python decorators painted as syntax errors (2026-09-14) —
  `Source/Highlighters/SynHighlighterPython.pas`: `'@'` was missing from the symbol set and
  `tkUnknown` maps to a red error attribute. Also a stray `;` after `then` that made a backslash
  guard unconditional, so a line-continued string never saw its terminator.
- C# verbatim (`@"C:\path\"`) and interpolated (`$"..."`) strings (2026-09-14) —
  `Source/Highlighters/SynHighlighterCS.pas`. The first swallowed the rest of the line because
  C-style backslash escaping was applied where `\` is not an escape; the second painted its `$` as
  an illegal character. New `rsVerbatimString` range and a `'$'` branch.
- XML: `DocTypeProc` left the range at `rsAttribute` where every other site uses `rsText`, and
  `CDATAProc` terminated on `]>` instead of `]]>` (2026-09-14) —
  `Source/Highlighters/SynHighlighterXML.pas`.
- **The `SYN_HEREDOC` path did not compile at all** (2026-09-14) —
  `Source/Highlighters/SynHighlighterRuby.pas`, `SynHighlighterPHP.pas`,
  `SynHighlighterUNIXShellScript.pas`. Three units passed a `WideChar` where `IsLineEnd` takes a
  `TSynNativeInt` — `E2010` — so enabling the define in `SynEdit.inc` broke the build in three
  places. On the same path, `CalcFCS` was given a **character** count where it walks bytes, so only
  half of a UTF-16 heredoc terminator was hashed and `EOX` would have terminated a `<<EOF` heredoc;
  both sides of each comparison were corrected together. Four `WideChar in [...]` set tests in the
  shell highlighter (`W1050`, truncating to the low byte) became `CharInSet`.
  **Now verified by compiling the whole runtime package with `-DSYN_HEREDOC`**: 0 errors,
  0 warnings. It was previously the least-verified change in this set.
- Unreachable attributes and token kinds (2026-09-14) — Haskell's `tkUnknown` had no arm in
  `GetTokenAttribute` (as-patterns rendered unstyled), C# had no `SYN_ATTR_SYMBOL` arm, Informix
  had no `tkPLSQL` branch and no sample source, CSS passed the wrong friendly-name constant so two
  attributes both displayed as "Attribute".
- Unicode identifiers no longer split on their first character in TypeScript and PHP, whose
  `IsIdentChar` accepts Unicode but whose dispatch did not (2026-09-14).
- Ruby `%=` parsed as a percent literal; `$` accepted as a leading identifier character in Java;
  `CRProc` tested the character after the LF in Cpp and CS (2026-09-14).

**Correctness of reported results**

- `TSynPositionEvent` macro streaming was asymmetric *and* platform-dependent (2026-09-14) —
  `Source/SynMacroRecorder.pas`. `SaveToStream` called `inherited` (Command + RepeatCount) and
  `LoadFromStream` did not, so every later event in the stream was misparsed; and
  `SizeOf(TBufferCoord)` is 8 bytes on Win32 and 16 on Win64, so a macro file was not portable
  between the two platforms this library ships. Now fixed-width `Int64` field-by-field.
  **This changes the on-disk macro format** — existing files will not load correctly.
- `TSynDataEvent` serialised a raw in-process `Pointer` and dereferenced it on playback
  (2026-09-14) — `Source/SynMacroRecorder.pas`. No longer persisted.
- `SynEditKeyCmdsEditor` raised `EListError "List index out of bounds (-1)"` out of its
  duplicate-shortcut handler (2026-09-14) — `Source/SynEditKeyCmdsEditor.pas`. The index was
  computed from `(Keystroke, Keystroke2)` but the raise comes from a search on `(Value, ShortCut2)`
  with `ShortCut2` still 0, so a chord whose first key duplicates a single-key shortcut gave -1 —
  and the escaping exception left a half-configured keystroke in the collection. Plausible cause of
  upstream issue **#266**.
- `ISpellChecker.Add`/`Ignore` HRESULTs discarded and the squiggle cleared before the word was
  added (2026-09-14) — `Source/SynSpellCheck.pas`. A read-only custom dictionary read as a flaky
  spell-checker. `SpellChecker` can also return nil, which both sites called through.
- `GetObject` and two DirectWrite HRESULTs unchecked, then `designUnitsPerEm` used as a divisor
  (2026-09-14) — `Source/SynDWrite.pas`. The unit checks the identical `GetObject` call correctly
  90 lines earlier.
- `TSynURIOpener` discarded `ShellExecute`'s result and marked a failed link as visited
  (2026-09-14) — `Source/SynURIOpener.pas`. New published `OnOpenError` event; the visited-list
  rollback is duplicate-aware because the list is sorted with `dupIgnore`. Also
  `GetAsyncKeyState(...) <> 0` accepted bit 0 ("pressed since the previous call"), so a Ctrl
  shortcut used elsewhere made the next mouse-move think Ctrl was held — now `GetKeyState`.
- `TSynTextRangeProvider.GetChildren` returned `S_OK` on failure and `S_FALSE` on success
  (2026-09-14) — `Source/SynAccessibility.pas`.
- `Assert(Assigned(Images))` guarded a nil dereference in a paint handler (2026-09-14) —
  `Source/SynCompletionProposal.pas`. `Images` is published, defaults to nil, and the component
  nils it itself on free notification; assertions are off in every stock Release configuration.
- `AddItemAt` destroyed the original exception and left its two lists misaligned on failure
  (2026-09-14) — `Source/SynCompletionProposal.pas`.

**Resource handling**

- OLE is initialised on first use instead of from a unit `initialization` section (2026-09-14) —
  `Source/SynEditDataObject.pas`, `Source/SynEdit.pas`. In a runtime package that section runs
  under the loader lock, where COM initialisation is unsafe; the HRESULT was discarded, so
  `RPC_E_CHANGED_MODE` from an MTA host went unnoticed and the `finalization` then uninitialised
  OLE for whoever *did* own it. The ownership flag is tri-state so that case is no longer claimed.
- A **shared** system cursor was handed to `TScreen.Cursors`, which calls `DestroyCursor` on the
  outgoing entry (2026-09-14) — `Source/SynURIOpener.pas`. Now a private copy via `CopyIcon`
  (`CopyCursor` is a C macro with no Pascal declaration).
- `HRGN` and `HDC` lifetimes wrapped in `try..finally` in `SynEditPrintPreview.PaintPaper` and
  `SynEditMiscProcs.GetCorrectFontWeight` (2026-09-14). The latter runs on every font change.
- `WeightEnumFontsProc` wrote 4 bytes through `PInteger` into an 8-byte result (2026-09-14) —
  `Source/SynEditMiscProcs.pas`, `Source/SynFunc.pas`. Correct only by accident of three unrelated
  facts. New `PSynNativeInt` in `SynFunc.pas`.


- `TargetedPlatforms` brought into line with the `<Platforms>` block in 1 `.dproj` (2026-09-10)
  The earlier platform sweep removed the non-Windows `<Platform>` entries but left the
  `<TargetedPlatforms>` bitmask untouched, so projects still advertised targets they no
  longer declared — values such as `1048579` and `135171` encode Android/Linux/iOS, and
  several Win32+Win64 projects still read `2` (Win64 only) or `1` (Win32 only).
  Now `3` for Win32+Win64, `2` where only Win64 is declared.
  **Why:** the mask is what the IDE reads for the Project Manager's platform list, so a
  stale one puts dead platforms back in front of the reader.

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
