# gllSynEdit — Help & Reference

Reference and troubleshooting for **gllSynEdit**, GITLAK's fork of
[TurboPack SynEdit](https://github.com/TurboPack/SynEdit): a syntax-highlighting editor control that
draws its own text through DirectWrite rather than wrapping a Windows common control.

**Target: Delphi 13 (RAD Studio 37.0) only, VCL only, Win32 and Win64.** Nothing else is built,
tested or supported here. Task-oriented walkthroughs are in [Users Guide.md](Users%20Guide.md);
installation and the upstream readme text are in `readme.md`; the fork delta — every change against
upstream, with the reason — is in `CHANGELOG.md`, and that file is the sole record of it.

---

## 1. Scope of this fork

### What we changed

| Change | Where it shows |
|---|---|
| **Delphi 13 is the compiler floor.** 78 dead `COMPILERVERSION` conditionals resolved away; only the four forward-looking `{$IF COMPILERVERSION >= 38}` deprecation markers remain | `SynDWrite.pas`, `SynEdit.pas`, `SynEditMiscClasses.pas`, `SynEditPrintPreview.pas`, `SynEditTextBuffer.pas`, `SynEditUndo.pas`, `SynEditWordWrap.pas`, `SynFunc.pas`, `SynUnicode.pas`, `Highlighters/SynHighlighterDelphi.pas` |
| **`Source/SynEditJedi.inc` deleted** — 2,160 lines, 646 version-bearing lines, 502 defines, none of which this library used. Proved by compiling the whole runtime package against an empty stub of it | `Source/SynEdit.inc` carries a comment where the include was |
| **Pre-D13 package folders deleted** — `Packages/Berlin`, `Tokyo`, `Rio`, `Sydney`, 60 files | `Packages/` holds only `11AndAbove/Delphi` |
| **C++Builder content deleted** — the `.cbproj`/`.cpp`/`.h` pair, the CB project groups, the `cpp` output tree. `DCC_CBuilderOutput` is `None` and `DCC_HppOutput`/`DCC_BpiOutput`/`DCC_ObjOutput` are gone from both projects | `Packages/11AndAbove/Delphi` |
| **Non-Windows conditionals resolved away**; `<Platforms>` normalised to Win32 + Win64 in all six `.dproj` files | `Source/`, `Demos/`, `Packages/` |
| **35 upstream defects fixed**, reviewed against upstream `ee3c6ba` — memory safety, data loss, out-of-bounds reads, editor hangs, wrong highlighting. The full write-up was **submitted to TurboPack on 2026-09-14** | listed individually under `CHANGELOG.md` → **Fixed** |
| **A DUnitX test suite** — the first automated tests this library has ever had | `Tests/` |
| **`build.cmd`** — one command that builds the packages, the demos and the tests in the order that works | repository root |
| **The Lib-DCU consumption model** — DCUs go to `37.0\$(Platform)\$(Config)` and consumers link those, instead of compiling SynEdit from source into every project | `SynEditDR.dproj`, `SynEditDD.dproj` |

### What we deliberately did not change

- **`Source/Highlighters/SynHighlighterDelphi.pas` is exempt from every mechanical directive pass.**
  Its keyword array contains the string literals `'initialization'` and `'finalization'`, so any
  pattern anchored on those words matches source that is not a directive. A regex attempt truncated
  600 lines of it; its three conditional sites were done by hand, by line number. Do the same.
- **The three hand-rolled `if (fOldRun = Run) and not GetEol then Next;` retries** in the HTML, PHP
  and XML highlighters were kept, not removed. They are load-bearing:
  `TSynXMLSyn.QAttributeValueProc` deliberately emits a zero-length token at an `&` and relies on the
  retry to re-dispatch into the new range. Removing them stalls `<root version="&test;">`.
- **`Demos/Folding/demo.cpp` is sample data, not C++Builder code.** It sits beside `demo.js` and
  `demo.py` as syntax-highlighting fodder for the folding demo. It stays.
- The upstream readme text, the MPL headers and `Doc/Contributors.txt` are left as written.

### Where the divergence is permanent

This fork has **real git ancestry** with upstream — `git merge-base` works, so
`git rev-list HEAD..upstream/master` is a truthful backlog count here. Take upstream by **fetching and
merging, never rebasing**. The consequence is that every edit to an upstream file is a conflict on
some future merge, and three of the changes above will conflict for certain:

- the deleted `Packages/Berlin|Tokyo|Rio|Sydney` folders (upstream still ships all four and last
  touched them on 2026-06-05) — **resolve with `git rm`, every time**;
- the deleted C++Builder projects — same resolution;
- the 35 defect fixes, because they were sent upstream and may come back in a different form. Resolve
  those in favour of whichever version is correct rather than assuming ours is the change.

Merged as far as `ee3c6ba` (2026-08-27), which is upstream's tip. Where a commit has already been
cherry-picked here, merge it anyway once it reaches a tip: the merge changes nothing, but without it
patch comparison keeps reporting a backlog that does not exist.

Two upstream branches were triaged on 2026-09-18 and **nothing was taken**:

- `11Alexandria` (`30cd5cc`) — declined by its own text, which edits that branch's README to say it
  is for legacy support only. One commit since a 2023 merge-base.
- `multicursor` (`fb9e365`) — declined, superseded. A 2020 experimental spike
  (`Source/SynEditMultiCaret.pas`, 1,180 new lines) abandoned upstream and replaced by the
  `TSynSelection`/`TSynSelections` design **this fork already carries**. **If you are looking for
  multi-caret support, it is already here** — see §5 and `Doc/Multi-caret.md`. Do not go looking for
  that branch.

---

## 2. The public surface

135 units, all of them in the two packages: 130 in `SynEditDR` (runtime), 5 in `SynEditDD`
(design-time). The palette pages are **SynEdit** and **SynEdit Highlighters**.

### The editor

| Unit | What it gives you |
|---|---|
| `SynEdit` | `TCustomSynEdit` and the published `TSynEdit`. Everything else attaches to this |
| `SynEditTypes` | `TBufferCoord`, `TDisplayCoord`, `TSynEditorOptions`, `TSynSearchOptions`, `SYNEDIT_DEFAULT_OPTIONS` |
| `SynEditTextBuffer` | `TSynEditStringList` — the `Lines` property's real type, a `TStrings` with per-line range and modification state |
| `SynEditMiscClasses` | `TSynGutter`, `TSynSelection`, `TSynSelections`, `TSynSelStorage`, `TSynIndicators`, `TSynIndicator`, `TSynIndicatorSpec`, `TSynBracketsHighlight`, `TSynScrollbarAnnotations`, `TSynIndentGuides` |
| `SynEditKeyCmds` | the `ec*` editor commands and `TSynEditKeyStrokes` |
| `SynEditUndo` | `ISynEditUndo`, reachable as `SynEdit.UndoRedo` |
| `SynDWrite` | the DirectWrite layer — `TSynTextFormat`, `TSynTextLayout`, `D2D1ColorF` |
| `SynFunc` | `TSynNativeInt`, `TSynNativeUInt`, `PSynNativeInt` — see §6 |
| `SynDBEdit` | `TDBSynEdit`, the data-aware editor |

### Highlighting

| Unit | What it gives you |
|---|---|
| `SynEditHighlighter` | `TSynCustomHighlighter`, `TSynHighlighterAttributes`, `RegisterPlaceableHighlighter`, `GetPlaceableHighlighters` |
| `SynEditCodeFolding` | `TSynCustomCodeFoldingHighlighter`, `TSynFoldRanges`, `TSynCodeFolding` |
| `Highlighters\Syn*Syn.pas` | 84 units. **82 register a placeable highlighter**; the two that do not are `SynHighlighterManager` (a design-time manager, in `SynEditDD`) and `SynHighlighterMulti` (`TSynMultiSyn`, which composes other highlighters by scheme) |
| `Highlighters\SynHighlighterOmni` | `TSynOmniSyn` — a *data-driven* highlighter configured from an `.ini` file. 189 language definitions ship in `Source\Highlighters\Omni Highlighters\` |
| `SynOmniSetupDialog` | the runtime editor for a `TSynOmniSyn` |

### Everything that plugs in

| Unit | Component | Purpose |
|---|---|---|
| `SynEditSearch` | `TSynEditSearch` | literal search engine |
| `SynEditRegexSearch` | `TSynEditRegexSearch` | PCRE search engine |
| `SynEditWildcardSearch` | `TSynEditWildcardSearch` | `*`/`?` wildcards, on top of the regex engine |
| `SynCompletionProposal` | `TSynCompletionProposal`, `TSynAutoComplete` | code completion and parameter hints |
| `SynAutoCorrect` | `TSynAutoCorrect` | as-you-type replacement list |
| `SynSpellCheck` | `TSynSpellCheck` + 11 registered actions | spell checking via the Windows `ISpellChecker` API |
| `SynMacroRecorder` | `TSynMacroRecorder` | record and play back keystroke macros |
| `SynEditPrint`, `SynEditPrintPreview` | `TSynEditPrint`, `TSynEditPrintPreview` | printing with headers, footers and margins |
| `SynExportHTML`, `SynExportRTF`, `SynExportTeX` | `TSynExporterHTML`, `TSynExporterRTF`, `TSynExporterTeX` | export highlighted text |
| `SynURIOpener` | `TSynURIOpener` | Ctrl-click a URL in the text |
| `SynEditOptionsDialog` | `TSynEditOptionsDialog` | ready-made options dialog |
| `SynEditPythonBehaviour` | `TSynEditPythonBehaviour` | Python indentation rules |
| `SynEditPlugins` | `TAbstractSynPlugin` and friends | the plugin base classes |
| `SynAccessibility` | — | UI Automation provider; `eoAccessibility` turns it on |

### Design-time only (`SynEditDD`)

`SynEditReg` (the registration itself), `SynEditPropertyReg`, `SynEditActionsResource`,
`Highlighters\SynHighlighterManager`, and `DesignTimeEditors\SynDelphiIDEImporter` — the
**Import IDE Settings** verb described in `What's New.md`.

---

## 3. What a highlighter has to satisfy

`Tests/TestHighlighterContract.pas` asserts these against **every class in
`GetPlaceableHighlighters`**, with no per-language knowledge, over 20 probe lines each of which has
broken a highlighter in practice. They are the invariants the editor depends on and that **no build
diagnoses** — a highlighter that breaks them compiles perfectly.

1. **Construction must not corrupt memory.** A keyword hash that indexes its dispatch table out of
   bounds does its damage in the constructor, before any file is opened.
2. **`Next` must consume at least one character or reach end of line.** Every scanning loop is
   `while not GetEol do Next`, so a token procedure that returns without advancing `Run` spins for
   ever inside a paint handler with the message loop blocked.
3. **`GetRange` must round-trip through `SetRange`, carrying *all* cross-line scanner state.** A
   field that is not in the range pointer is lost when the editor repaints from mid-document.
4. **A highlighter must scan its own `SampleSource` identically** whether the range is restored per
   line or not.

Invariant 2 is now enforced centrally: `TSynCustomHighlighter.Next` is the library's single
scanner-progress guard. All 82 registered highlighters end their `Next` with `inherited`, so the base
class covers every one of them — it asserts (naming the highlighter and the column) and forces
progress, degrading a scanner defect to wrong colours on one line instead of an unkillable freeze.
This is the shape of upstream issue **#261**, *"CSS highlighter locks up application"*.

The guard compares `Run` against **`fTokenPos`**, not the `fOldRun` field: `fOldRun` is a field, so
the HTML/PHP/XML highlighters' re-entrant `Next` call updated it and made the test trivially true on
the way out.

---

## 4. Non-ASCII content in the sources is DATA, not prose

Two places will look like stray foreign-language text to a reviewer, a translator or a mechanical
pass. Both are reference data and must be left byte-for-byte alone:

- **`Highlighters/SynHighlighterHtml.pas` carries the HTML named-entity tables** — 257 keywords,
  including `&Auml;`, `&auml;`, `&nbsp;` and the rest, each with the glyph it produces in a trailing
  comment. `HashKey` and `KeyIndices` are generated *together* from that list: when `HashKey` stopped
  consuming `'!'` but `KeyIndices` did not, `!doctype` became unrecognisable (fixed here; verified
  numerically — 255 of 257 round-tripped before, 257 after).
- **`Highlighters/SynHighlighterJava.pas` contains the character range
  `'L'..'Ö', 'Ø'..'ö', 'ø'..'ÿ'`** in `TSynJavaSyn.IsIdentChar` — twice, and **both occurrences are
  inside comments** (a `(* … *)` block at line 1108 and a `//`-commented line at 995). The live
  implementation is `IsCharAlphaNumeric(AChar) or CharInSet(AChar, ['_', '$'])`. So the range is
  historical, not executable — but it is still source data, not text to be "corrected".

---

## 5. Multi-caret editing

Multiple carets are a first-class part of this codebase, built on `TSynSelection` (a record) and
`TSynSelections` (the collection), both in `SynEditMiscClasses`. `TCustomSynEdit` exposes them as
`Selection` (the active one) and `Selections`. `Doc/Multi-caret.md` is the design note.

Points that catch people out:

- `CaretXY`, `BlockBegin`, `BlockEnd`, `SelStart`, `SelEnd`, `SelText`, `SetCaretAndSelection` and
  the rest all operate on the **active selection only**, exactly as they did before.
- Each command carries a `TSynCommandKind` — `ckStandard`, `ckSingleCaret` or `ckMultiCaret`.
  `CommandProcessor` runs a multi-caret command once per caret; a single-caret command cancels the
  extra carets first, keeping the base selection. **`ExecuteCommand` only ever affects the active
  selection** — use `CommandProcessor` when you want the multi-caret behaviour.
- The old selection-mode API is **gone**: no `eoAltSetsColumnMode`, no `ecSelectNormal`,
  `ecSelectLine` or `ecSelectColumn`. `UpdateCaret` is now `UpdateCarets`.
- To save and restore, you need `Selections.Store(SelStorage)` / `Selections.Restore(SelStorage)` —
  storing `CaretXY` and the block bounds captures one selection out of however many exist.
- **Printing and print preview do not support multiple selections.** They work on the active
  selection, as before.

---

## 6. `TSynNativeInt` — the trap that only Win64 reveals

`Source/SynFunc.pas` declares `TSynNativeInt = NativeInt`, `TSynNativeUInt = NativeUInt` and
`PSynNativeInt = ^TSynNativeInt`. **On Win32 `NativeInt` *is* `Integer`, so a mismatch is invisible;
on Win64 it is 64-bit and everything breaks.** That is why eight of the twelve demos could not build
for Win64 while all twelve built for Win32.

Two shapes to watch for:

- An event handler or virtual override declaring `Integer` where the library uses `TSynNativeInt`:
  `E2037 Declaration ... differs from previous declaration`, followed by a cascade of
  undeclared-identifier errors that makes the fault look far larger than it is. Frequently only the
  *implementation* is wrong while the interface was already updated.
- A hard cast of `TBufferCoord` to `TPoint`. Valid while the fields are 4 bytes,
  `E2089 Invalid typecast` once they are 8. Copy the fields across instead.

**The trap runs in both directions.** After `TSynDWSSyn.HashKey` was correctly restored to `Cardinal`,
the **Win32** build — and only Win32 — produced nine `W1071` narrowings, because the helper it fed
still took a `NativeInt`, which is 32-bit there. Each platform hides a different half of this, so
**always build both**.

Use plain `NativeInt` in new code: on Delphi 13 it is the same type and needs no extra `uses` entry,
and the demos already do.

---

## 7. Building

`build.cmd` at the repository root does everything, in the order that works, and exits non-zero on
any failure:

```
build.cmd            packages + demos + tests
build.cmd packages   the two packages only, four modes each
build.cmd tests      the test suite only, both platforms
```

It expects RAD Studio 37.0 at `C:\Program Files (x86)\Embarcadero\Studio\37.0` (edit `BDS_DIR` at the
top if yours differs) and DUnitX at `%DUNITX%`, defaulting to `D:\gllDUnitX\Source`.

- **Packages: `SynEditDR` then `SynEditDD`, Win32 + Win64 × Debug + Release — 8 builds.** The order
  is load-bearing; see §8. The two packages between them contain all 135 units, so a package build is
  already a full compile check of the library.
- **Demos: the 12 projects under `Demos\`, both platforms.** They are the only consumers of the
  public API in this repository, so build them after any change to a public type. They have caught a
  real problem already.
- **Tests: `Tests\SynEditTests.dproj`, Debug, both platforms**, then run the exe.

Output follows the estate package standard, set in both `.dproj` files:

```xml
<DCC_DcuOutput>..\..\..\37.0\$(Platform)\$(Config)</DCC_DcuOutput>
<DCC_BplOutput Condition="'$(Config)'=='Release'">$(BDSCOMMONDIR)\Bpl\$(Platform)</DCC_BplOutput>
<DCC_BplOutput Condition="'$(Config)'!='Release'">$(BDSCOMMONDIR)\Bpl\$(Platform)\$(Config)</DCC_BplOutput>
<DCC_DcpOutput Condition="'$(Config)'=='Release'">$(BDSCOMMONDIR)\Dcp\$(Platform)</DCC_DcpOutput>
<DCC_DcpOutput Condition="'$(Config)'!='Release'">$(BDSCOMMONDIR)\Dcp\$(Platform)\$(Config)</DCC_DcpOutput>
```

Release BPLs and DCPs stay in the shared platform folders — that is what is on `PATH` and where
dependent packages resolve their `requires` — and only Debug is diverted to a `$(Config)` subfolder,
so a Debug build cannot replace the installed Release package. DCUs are per-platform *and*
per-config, which is what stops a Win32 build overwriting Win64 DCUs.

A post-build event on the runtime package copies `Source\*.dfm` and `Source\*.res` beside the DCUs,
because `{$R}` resources bind at **link** time and consumers do not have `Source` on their search
path.

### How the estate consumes it

Not by source, and not by runtime package. Consumers link the **Release DCUs** from the library path:

| IDE setting (per platform) | Value |
|---|---|
| Library path | `D:\gllSynEdit\37.0\<Platform>\Release` |
| Debug DCU path | `D:\gllSynEdit\37.0\<Platform>\Debug` |
| Browsing path | `D:\gllSynEdit\Source`, `D:\gllSynEdit\Source\Highlighters` |

The browsing path entries are what make Ctrl-click navigation reach the source; they are deliberately
**not** on the library path, because putting `Source` there makes every consuming project recompile
the library into its own divergent DCU set.

`DBiReportsScanEdit` is the estate's real consumer: `MainFrm.pas` names `SynEdit`, `SynEditTypes`,
`SynEditMiscClasses` and `SynDWrite` in its uses clause and hosts a `TSynEdit` on its main form. It
links statically — no DBiWorkflow application sets `<UsePackages>true</UsePackages>` — so **a library
fix reaches it only when that application is rebuilt**; rebuilding the packages is not enough.

`DBiMiniTimeSync` and `DBiTimeSync` carry `SynEditDR` in their `DCC_UsePackage` lists. That is
inherited IDE boilerplate, inert with runtime packages off, and neither project uses the editor.

---

## 8. Troubleshooting

### `E2225 Never-build package 'SynEditDR' must be recompiled`

You built the **design-time** package first. `SynEditDD` requires `SynEditDR`'s `.dcp`. Build the
runtime package for that platform and configuration first, or just use `build.cmd packages`, which
encodes the order.

### `Packages/11AndAbove/Delphi/SynEditDD.res` shows as modified after a build

Expected, and it loses content: MSBuild rewrites that tracked file from **4,812 bytes to 640**.
`build.cmd` reverts it for you. If you built by hand:

```
git checkout -- Packages/11AndAbove/Delphi/SynEditDD.res
```

Do this **before committing**, or the 640-byte version becomes the tracked one.

### `E2037 Declaration ... differs from previous declaration`, Win64 only

An `Integer` where the library uses `TSynNativeInt`. See §6. Check the *implementation* as well as
the interface — usually only one of the two was updated.

### `E2089 Invalid typecast` on a `TBufferCoord`

A hard cast to `TPoint`, which stops being valid once the fields are 8 bytes. Copy `Char`/`Line` into
`X`/`Y` instead. Same root cause as above.

### `F2039 Could not create output file '...SynEditDD370.bpl'`

The IDE has that design-time package loaded and is holding the file. The compile itself succeeded;
this is a lock, not a code error. Close `bds.exe` (or uninstall the package) and build again.
**Never pass a clean build while the IDE holds the package** — `CleanOutputs` deletes the `.dcp`
first and only then fails to delete the `.bpl`, leaving consumers with
`E2202 Required package 'SynEditDR' not found` and no way to regenerate it until the IDE closes.

### `Error Reading Form: Class TSynEdit not found` in the designer

The design package is registered against the wrong IDE bitness. `SynEditDD` must be installed from
**`bin64\bds.exe`**; `Known Packages` (32-bit) and `Known Packages x64` are separate lists, and a
package registered in the wrong one can never load. **Do not click Ignore on that dialog** — it drops
the component and its property values out of the form, and saving writes the loss into the `.dfm`.

### The editor freezes solid while typing, with one core pinned

A highlighter whose `Next` consumed nothing. Since 2026-09-14 the base-class guard turns this into an
assertion plus wrong colours on one line rather than a freeze, so if you are seeing the freeze you are
running an older build, or a highlighter that does not call `inherited` at the end of its `Next`. See
§3.

### Colours are wrong only after scrolling back into a region

Cross-line scanner state that `GetRange` does not carry. The editor repaints from the middle of the
document by restoring a range; anything the highlighter keeps in a field instead of packing into the
range pointer is silently lost. `TSynSQLSyn` does this correctly for its Oracle q-quote delimiter and
is the model. `Tests/TestHighlighterContract.RangeRoundTrips` catches it.

### A recorded macro will not load, or loads as nonsense

`TSynPositionEvent` streaming was asymmetric and platform-dependent — `SizeOf(TBufferCoord)` is 8
bytes on Win32 and 16 on Win64, so a macro file was never portable between the two platforms this
library ships. Fixed here by writing fixed-width `Int64` fields. **This changed the on-disk macro
format**: macro files recorded before the fix will not load correctly. `TSynDataEvent` used to
serialise a raw in-process `Pointer` and dereference it on playback; it is no longer persisted at all.

### A `TSynSpellCheck` constructor raises

`TSynSpellCheck` is a **singleton** — the constructor raises `ESynError` if `GlobalInstance` is
already assigned. One instance per application; use `AddEditor`/`RemoveEditor` to attach it to more
than one editor.

### `TSynOmniSyn.LoadFromIniFile` will not take my `TCustomIniFile`

`TSynOmniSyn` declares `LoadFromIniFile(const FileName: string): Boolean` and
`SaveToIniFile(const FileName: string): Boolean`, which **hide** the base class's
`LoadFromIniFile(AIni: TCustomIniFile): Boolean`. Pass a path. If you need the `TCustomIniFile`
form, call it through a `TSynCustomHighlighter` reference.

### `H2675 Directory not found` mentioning a path under this repository

A stale unit search path. Nothing in this repository needs `$(BDS)\Source\DUnit\src` or an `hpp`
directory — the latter was upstream's C++Builder install step and this fork emits no `.hpp` at all.

---

## 9. Tests

`Tests/SynEditTests.dproj` is a DUnitX console runner, built Debug for both platforms and run by
`build.cmd tests`. **7/7 as of 2026-09-14.** A package build is a *compile* check and does not
substitute for it.

- `TestHighlighterContract` — the four contract tests of §3, data-driven over
  `GetPlaceableHighlighters`. It found a real non-advancing `Next` in `TSynXMLSyn` on its first run.
- `TestTextBuffer` — the `TSynEditStringList` defects fixed in this fork. All three are
  mutation-proved: reverting each fix independently turns exactly one test red. The two
  double-release tests assert the **reference-count delta** across `Clear`, which must be exactly 1,
  because merely reading freed memory does not reliably fault.

Two things about the runner to know before you add a fixture:

- **Every highlighter unit is linked explicitly in `SynEditTests.dpr`.** Each registers itself from
  its own initialization section, so a unit that is not linked is simply absent from
  `GetPlaceableHighlighters` and would be silently skipped rather than reported as missing.
- **`Runner.UseRTTI` is `False`**, so a fixture is discovered *only* through
  `TDUnitX.RegisterTestFixture` in its unit's `initialization` section. Both existing fixtures do
  that. A new fixture carrying only a `[TestFixture]` attribute will compile, link, and never run —
  the test count simply will not move.

`Assert.IgnoreCaseDefault := False` is set in the runner mainline, so string assertions in this suite
are case-sensitive by construction.

---

## 10. Third-party dependencies

None at runtime. The library is pure VCL plus the Windows APIs it draws and speaks through —
DirectWrite/Direct2D (`SynDWrite`), UI Automation (`SynAccessibility`), OLE drag-and-drop and
clipboard (`SynEditDataObject`, `SynEditDragDrop`), IMM for the IME, and `ISpellChecker`
(`SynSpellCheck`). `TSynEditRegexSearch` uses the RTL's own `System.RegularExpressionsCore`.

The **test suite** needs DUnitX on its unit search path — `D:\gllDUnitX\Source` here — and nothing
else does.
