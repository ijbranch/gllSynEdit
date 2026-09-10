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
  be re-added. **Two files were deliberately left untouched by that sweep**, because
  their directive nesting is unbalanced by design and a mechanical resolve would
  corrupt them: `Source/SynEditJedi.inc` (which still carries `MSWINDOWS` and other
  platform conditionals) and `Source/Highlighters/SynHighlighterDelphi.pas`. Leave
  both alone.
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

The only package set built here is `Packages/11AndAbove/Delphi`:
`SynEditDR` (runtime) then `SynEditDD` (design-time). **Win32 + Win64 x Debug +
Release, 8 of 8 pass.**

Those two packages contain all 135 units under `Source`, so a package build is
already full coverage — there is no separate compile test to run, and no
equivalent of glldzlib's AllUnits harness is needed.

The 12 demos under `Demos/` build for **Win32 and Win64**. Build them after any
change to the library's public types; they are the only consumers in the
repository and they caught a real problem once already.

## The `TSynNativeInt` trap

`Source/SynFunc.pas` declares:

```pascal
{$IF COMPILERVERSION < 36}
  TSynNativeInt = Int32;
{$ELSE}
  TSynNativeInt = NativeInt;
{$IFEND}
```

From Delphi 12 on it is `NativeInt`. **On Win32 `NativeInt` is `Integer`, so a
mismatch is invisible; on Win64 it is 64-bit and everything breaks.** This is
upstream's declaration, and it is the reason eight of the twelve demos could not
build for Win64 until 2026-08-28 while all twelve built for Win32.

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
