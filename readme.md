# TurboPack SynEdit

The master branch supports **Delphi 12 Athens** and **Delphi 13 Florence** (COMPILERVERSION 36 and 37), Win32 and Win64, VCL. You can also access the [11 Alexandira](https://github.com/TurboPack/SynEdit/tree/11Alexandria), [10.3 Rio](https://github.com/TurboPack/SynEdit/releases/tag/103RIO), [10.2 Tokyo](https://github.com/TurboPack/SynEdit/releases/tag/102Tokyo) and [10.1 Berlin](https://github.com/TurboPack/SynEdit/releases/tag/101Berlin) releases. Keep in mind they don't have the latest updates.

> **In this fork:** `gllSynEdit` is scoped to **Delphi 13 (RAD Studio 37.0) and later**, Win32 and Win64. The older-release links above are upstream's; nothing here is built or tested against them. Because Delphi 13 is the floor here, the compiler-version conditionals below it have been resolved away and `SynEditJedi.inc` has been deleted - see `CHANGELOG.md`.
>
> A review of upstream `ee3c6ba` found 35 defects, all fixed here and **submitted to TurboPack on 2026-09-14**. Some may therefore return through a future merge.

### Table of contents
1.  [Introduction](#Introduction)
2.  [Package names](#Package-names)
3.  [Installation](#Installation)
4.  [Building and testing](#Building-and-testing)
5.  [Documentation](#Documentation)

---

## Documentation

| For | Read |
|---|---|
| Something failed, or you need the unit map — the public surface, what a highlighter must satisfy, the `TSynNativeInt` trap, 11 symptom rows | [Help.md](Help.md) |
| Doing a job — first editor, highlighters, folding, search, multiple carets, indicators, completion, spell check, export | [Users Guide.md](Users%20Guide.md) |
| What changed and when | [CHANGELOG.md](CHANGELOG.md) |

## Fork Reason (gllSynEdit)

This repository is **gllSynEdit**, GITLAK's fork of
[TurboPack SynEdit](https://github.com/TurboPack/SynEdit), scoped to
**Delphi 13+**, Win32 and Win64, and installed into the 64-bit RAD Studio IDE.
Upstream content is kept unmodified except where `CHANGELOG.md` — the sole
record of the fork delta — says otherwise. Take upstream updates by fetching
the `upstream` remote and merging (never rebasing).

**Merged as far as `e106252` (2026-10-11), which is upstream's tip.** Where a
commit has already been cherry-picked here, merge it anyway once it reaches a
tip: the merge changes nothing, but without it `git rev-list HEAD..upstream/master`
keeps reporting a backlog that does not exist, because patch comparison cannot
recognise an adapted cherry-pick.

(The section heading is inherited from upstream, whose readme still carries a
leftover fork note from the contributor of the WebStencils highlighter.)

## Introduction

![SynEdit](https://raw.githubusercontent.com/TurboPack/SynEdit/master/Doc/SynEdit-1.3.png "TurboPower SynEdit")


SynEdit is a syntax highlighting edit control, not based on the Windows 
common controls. SynEdit is a Delphi component.

This is a source-only release of TurboPack SynEdit. It includes
designtime and runtime packages for Delphi and supports Win32 and Win64.

---

## Package names

TurboPack SynEdit package names have the following form:

Delphi
* SynEditDR.bpl (Delphi Runtime)
* SynEditDD.bpl (Delphi Designtime)

> **Delphi-only fork.** `gllSynEdit` has only `SynEditDR` and `SynEditDD`
> (under `Packages\11AndAbove\Delphi`); those are built, installed and supported
> here. The upstream `Packages\11AndAbove\CBuilder\` projects (`SynEditCR.bpl`,
> `SynEditCD.bpl`) were never compiled here and were **deleted 2026-09-10**, along
> with the `cpp` output folder. As of 2026-08-26 the two Delphi packages also have
> `DCC_CBuilderOutput=None`, and as of 2026-09-10 they no longer carry
> `DCC_HppOutput`/`DCC_BpiOutput`/`DCC_ObjOutput` at all, so they emit none of the
> `.hpp`/`.bpi`/`.a`/`.obj` files a C++Builder consumer would need — that alone was
> 560 files regenerated on every build for a compiler this estate does not use.
> Re-add them on those two projects if you ever genuinely need C++ interop.

---

## Installation

TurboPack SynEdit is available via the [GetIt Package Manager](http://docwiki.embarcadero.com/RADStudio/en/Installing_a_Package_Using_GetIt_Package_Manager) where you can quickly and easily install and uninstall it.

To manually install TurboPack SynEdit into your IDE, take the following
steps:

1. Unzip the release files into a directory (e.g., d:\SynEdit).

2. Start RAD Studio.

3. Add the **Source** and the **Source\Highlighters** subdirectories to the IDE's library path.

> Upstream's extra step here — adding an hpp subdirectory to the C++Builder system include path — does not apply to this fork: `gllSynEdit` builds no C++ packages and emits no `.hpp`, so there is no hpp subdirectory to add. See the note under **Package names** above.

4. Add the **Source\DesignTimeEditors** subdirectory as well if you intend to build the
design-time package from source.

5. Open & install the design-time package specific to the IDE being used. The IDE should notify you the components have been
installed. In this fork that is `Packages\11AndAbove\Delphi\SynEditDD.dproj`, and it must be
installed from the **64-bit** IDE (`bin64\bds.exe`) — design packages register per IDE bitness.

---

## Building and testing

`build.cmd` at the repository root builds and tests everything, in the order that works:

```
build.cmd            packages + demos + tests
build.cmd packages   the two packages only, four modes each
build.cmd tests      the test suite only, both platforms
```

It exits non-zero if any build fails or any test fails, so it is usable as a pre-commit check.
To run one fixture of the built suite: `SynEditTests.exe --run:TestWordNavigation.TWordNavigationTests`
( DUnitX's own option; a filter that matches nothing exits 250, and a crash outside the tests exits 2 ).

* **Packages** — `SynEditDR` (runtime) then `SynEditDD` (design-time), Win32 + Win64 x Debug +
  Release, 8 builds. The order matters: building the design-time package first fails `E2225`
  because it requires the runtime package's `.dcp`.
* **Demos** — the 12 projects under `Demos\`, both platforms. They are the only consumers of the
  public API in the repository, so build them after any change to a public type.
* **Tests** — `Tests\SynEditTests.dproj`, a DUnitX console runner, both platforms. It needs
  DUnitX on the unit search path; `build.cmd` passes `%DUNITX%`, defaulting to
  `D:\gllDUnitX\Source`.

`TestHighlighterContract` is data-driven over `GetPlaceableHighlighters`, so it asserts the
scanning contract against **all 83 registered highlighters** at once, with no per-language
knowledge:

* `Next` consumes at least one character or reaches end of line — a token procedure that returns
  without advancing `Run` spins the scanning loop for ever, inside a paint handler;
* `GetRange` round-trips through `SetRange`, and carries **all** cross-line scanner state — a
  field that is not in the range pointer is lost when the editor repaints from mid-document;
* each highlighter scans its own `SampleSource` identically whether the range is restored per
  line or not.

Those are the invariants the editor depends on and that no build diagnoses. A highlighter that
breaks them compiles perfectly.

**Note:** building `SynEditDD` makes MSBuild rewrite the tracked
`Packages\11AndAbove\Delphi\SynEditDD.res`, shrinking it from 4,812 bytes to 640. `build.cmd`
reverts it; if you build by hand, `git checkout --` it before committing.

---

## Documentation

* [Code folding](Doc/CodeFolding.md) — how `TSynCustomCodeFoldingHighlighter` works and how to
  add folding to a highlighter.
* [Multi-caret editing](Doc/Multi-caret.md).
* [`What's New.md`](What's%20New.md) — `TSynDelphiSyn` and the IDE settings importer.
* [`CHANGELOG.md`](CHANGELOG.md) — in this fork, the sole record of the delta against upstream.
