# TurboPack SynEdit

The master branch remains compatible with Delphi 12 Athens or later. You can also access the [11 Alexandira](https://github.com/TurboPack/SynEdit/tree/11Alexandria), [10.3 Rio](https://github.com/TurboPack/SynEdit/releases/tag/103RIO), [10.2 Tokyo](https://github.com/TurboPack/SynEdit/releases/tag/102Tokyo) and [10.1 Berlin](https://github.com/TurboPack/SynEdit/releases/tag/101Berlin) releases. Keep in mind they don't have the latest updates.

> **In this fork:** `gllSynEdit` is scoped to **Delphi 13 (RAD Studio 37.0) and later**, Win32 and Win64. The older-release links above are upstream's; nothing here is built or tested against them.

### Table of contents
1.  [Introduction](#Introduction)
2.  [Package names](#Package-names)
3.  [Installation](#Installation)

---

## Fork Reason (gllSynEdit)

This repository is **gllSynEdit**, GITLAK's fork of
[TurboPack SynEdit](https://github.com/TurboPack/SynEdit), scoped to
**Delphi 13+**, Win32 and Win64, and installed into the 64-bit RAD Studio IDE.
Upstream content is kept unmodified except where `CHANGELOG.md` — the sole
record of the fork delta — says otherwise. Take upstream updates by fetching
the `upstream` remote and merging (never rebasing).

**Merged as far as `ee3c6ba` (2026-08-27), which is upstream's tip.** Where a
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

4. Open & install the design-time package specific to the IDE being used. The IDE should notify you the components have been
installed.
