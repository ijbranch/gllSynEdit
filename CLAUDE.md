# gllSynEdit — project instructions

GITLAK fork of **TurboPack SynEdit** (`https://github.com/TurboPack/SynEdit`).
`CHANGELOG.md` is the sole record of the fork delta; `readme.md` carries the
merged-through marker.

## Scope

- **Delphi 13 (Florence, RAD Studio 37.0) and later.** D13+ is the global floor
  for every project and package (Ian, 2026-08-28).
- **Windows and VCL only.** Never Win64x. No non-Windows
  `{$IFDEF POSIX|LINUX|ANDROID|IOS|MACOS|OSX|UNIX}` construct is left in `Source`
  (verified 2026-09-10); there is no Linux/macOS/mobile support here and none is to
  be re-added. **One file is still deliberately left untouched by mechanical directive
  passes**, because its nesting is unbalanced by design and a resolver would corrupt it:
  `Source/Highlighters/SynHighlighterDelphi.pas` — its keyword array contains the string
  literals `'initialization'` and `'finalization'`, so a pattern anchored on those words
  matches source that is not a directive. Do its conditionals by hand, by line number.
  **`Source/SynEditJedi.inc` was the other such file and is gone** (deleted 2026-09-14,
  2,160 lines): nothing in the tree used any of the 502 symbols it defined, proved by
  compiling the whole runtime package against an empty stub of it.
- **Win32 and Win64, both supported and both built** -- Win32 + Win64 x Debug +
  Release, the suite-wide four-mode package rule, which is what the 8/8 figure
  below counts. This **supersedes** an earlier "Win64 only" scope (Ian,
  2026-08-28); if you find that phrase anywhere it is stale, not a distinction.
- **C++Builder is never in scope, and is now gone from the tree.**
  `Packages/11AndAbove/CBuilder/` (the `SynEditCD`/`SynEditCR` `.cbproj` pair, their
  `.cpp` files and the `SynEditCBuilder.groupproj`) and the `cpp` output folder were
  deleted 2026-09-10. The Delphi `.dproj` files carry `DCC_CBuilderOutput=None` and
  no longer carry `DCC_HppOutput`/`DCC_BpiOutput`/`DCC_ObjOutput` at all. Expect a
  delete/modify merge conflict if upstream touches those files; resolve it with
  `git rm`, as with the pre-D13 package folders below.
  `Demos/Folding/demo.cpp` is NOT C++Builder code and was deliberately kept: it is
  syntax-highlighting sample data beside `demo.js` and `demo.py`. Do not remove it.

## Upstream: merge, never rebase

Take upstream by fetching the `upstream` remote and merging. Real git ancestry
exists — `git merge-base` works, so `git rev-list HEAD..upstream/master` is a
truthful backlog count here, unlike the gll* forks that were seeded from a
release.

**This is the single most important difference from `glldzlib`.** That fork is an
SVN snapshot with no shared history, so mass edits there cost nothing. Here every
edit to an upstream file is a conflict on some future merge. Keep changes
minimal, targeted, and recorded in `CHANGELOG.md`.

### The pre-D13 package folders were removed

`Packages/Berlin`, `Tokyo`, `Rio` and `Sydney` are pre-D13 and built nothing
here. Removed 2026-08-28 (Ian) -- 60 files. Do not restore them.

**Expect merge conflicts, and resolve them by keeping the deletion.** Upstream
still ships all four, 15 files each, and last touched them on 2026-06-05, so a
future `git merge upstream/master` that changes any of those files will raise a
delete/modify conflict. The resolution is `git rm` on the path, every time --
the removal is deliberate, not an accident to be undone.

That is the cost this fork accepted for a smaller tree, and it is the one place
where the merge-never-rebase rule above will actually bite.
## Build verification

**`build.cmd` at the repository root does all of the below in the order that works, and
exits non-zero on any failure** - `build.cmd` (packages + demos + tests), `build.cmd
packages`, `build.cmd tests`. Prefer it to driving MSBuild by hand; it encodes the package
order.

**Build auto-increment is on in both packages (2026-10-12)**, so every build bumps
`VerInfo_Build` in the `.dproj` and rewrites the package `.res`; commit both. Delphi writes the
number only into a config-and-platform group (`Cfg_1_*` = Release, `Cfg_2_*` = Debug here), so
do not delete those groups as empty-looking. The BPL's file version lags the `.dproj` counter by
one build. These two `.dproj` files now diverge from upstream, so a future merge touching them
may conflict: keep ours plus upstream's real change.

The only package set built here is `Packages/11AndAbove/Delphi`:
`SynEditDR` (runtime) then `SynEditDD` (design-time). **Win32 + Win64 x Debug +
Release, 8 of 8 pass.**

Those two packages contain all 136 units under `Source`, so a package build is
already full coverage as a *compile* test — there is no separate compile harness to
run, and no equivalent of glldzlib's AllUnits.

**The runtime package compiles with zero warnings and zero hints under
`dcc64 -H -W`** as of 2026-09-14, and it is worth keeping it that way: the single
worst defect found in the 2026-09-14 review (`TSynDWSSyn` writing outside its
method-pointer table) was introduced by an upstream commit called "Removed some
warnings". A new warning here is a signal, not noise. Only `W1048` (191, the
`TMethod` and property-editor casts) and `W1076` (148, the `GetRange: Pointer`
protocol) remain, and both are inherent to those designs.

The 12 demos under `Demos/` build for **Win32 and Win64**. Build them after any
change to the library's public types; they are the only consumers in the
repository and they caught a real problem once already.

**`Tests/SynEditTests.dproj` is the behavioural gate, and a package build does not
substitute for it.** `TestHighlighterContract` is data-driven over
`GetPlaceableHighlighters`, so it asserts the scanning contract against all 83
registered highlighters at once: `Next` advances or reaches end of line, `GetRange`
round-trips through `SetRange`, and each highlighter scans its own `SampleSource`
identically whether the range is restored per line or not. Run it for both
platforms; it needs `D:\gllDUnitX\Source` on the unit path. **12/12 as of 2026-09-23**
(7 until `TestWordNavigation` pinned Ctrl+Left / Ctrl+Right, which had no coverage at
all when upstream changed their character rule).
It found a real non-advancing `Next` in `TSynXMLSyn` on its first run — that class
of defect compiles perfectly and hangs the editor, so nothing else catches it.

**Building `SynEditDD` used to rewrite `Packages/11AndAbove/Delphi/SynEditDD.res`**
from 4,812 bytes to 640, losing content, and this section said to revert it before
committing. **That no longer fires** (measured 2026-09-23): the 640-byte form is what
is tracked at HEAD, and a full eight-configuration package build leaves the file
untouched - `git diff` on it is empty afterwards. The history is
`2911904` 640 -> `292582d` 4,812 -> `95f6149` 640.
Still worth a glance at `git status` after a design-time build, because the file IS
tracked on purpose; just do not expect a revert to be needed.

## The `TSynNativeInt` trap

`Source/SynFunc.pas` declares:

```pascal
  TSynNativeInt = NativeInt;
  TSynNativeUInt = NativeUInt;
  PSynNativeInt = ^TSynNativeInt;
```

(The `{$IF COMPILERVERSION < 36}` guard that used to wrap this, giving `Int32` on
older compilers, was resolved away on 2026-09-14 along with the other 77 dead
version conditionals — Delphi 13 is the floor here, so it could never be taken.
Upstream still carries it.)

**On Win32 `NativeInt` is `Integer`, so a mismatch is invisible; on Win64 it is
64-bit and everything breaks.** That is the reason eight of the twelve demos could
not build for Win64 until 2026-08-28 while all twelve built for Win32.

**The trap runs in both directions, and the 2026-09-14 sweep hit the other one:**
after `TSynDWSSyn.HashKey` was correctly restored to `Cardinal`, the **Win32** build
— and only Win32 — produced nine `W1071` narrowings, because the helper it fed still
took a `NativeInt` and `NativeInt` is 32-bit there. Build both platforms; each hides
a different half of this.

Two shapes to watch for when touching or importing this code:

- An event handler or virtual override declaring `Integer` where the library
  uses `TSynNativeInt` — `E2037 Declaration ... differs from previous
  declaration`, then a cascade of undeclared-identifier errors that makes the
  fault look far larger than it is. Frequently only the *implementation* is
  wrong while the interface was already updated.
- A hard cast of `TBufferCoord` to `TPoint`. Valid while the fields are 4 bytes,
  `E2089 Invalid typecast` once they are 8.

Use `NativeInt` in new code: on Delphi 13 it is the same type and needs no extra
`uses` entry, and the demos already use it.

**A Win32-only build proves nothing about this.** Always build both platforms.

## Repository hygiene

`.gitignore` is deliberately self-contained: it does not rely on the cloning
machine having any particular `core.excludesFile`. Build output directories
(`37.0/`, `Packages/*/Delphi/Win32|Win64/`, `Packages/*/cpp/`) are excluded here,
not just by a global file — the extension rules alone miss the `.dfm` and `.res`
the compiler copies into them.

Note the deliberate exception `!Packages/11AndAbove/Delphi/*.res`: those package
resources are tracked on purpose. After changing any ignore rule, check nothing
tracked became ignored:

```sh
git ls-files | git check-ignore --stdin -v
```

It must print nothing.
