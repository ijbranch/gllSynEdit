# gllSynEdit — project instructions

GITLAK fork of **TurboPack SynEdit** (`https://github.com/TurboPack/SynEdit`).
`CHANGELOG.md` is the sole record of the fork delta; `readme.md` carries the
merged-through marker.

## Scope

- **Delphi 13 (Florence, RAD Studio 37.0) and later.** D13+ is the global floor
  for every project and package (Ian, 2026-08-28).
- **Windows, VCL, Win32 + Win64.** Never Win64x.
- **C++Builder is never in scope.** `Packages/*/CBuilder/` is upstream content
  this fork carries but never compiles. The Delphi `.dproj` files carry
  `DCC_CBuilderOutput=None`; the `.cbproj` files still say `All`, which is
  correct — they *are* C++ projects, and nothing here builds them.

## Upstream: merge, never rebase

Take upstream by fetching the `upstream` remote and merging. Real git ancestry
exists — `git merge-base` works, so `git rev-list HEAD..upstream/master` is a
truthful backlog count here, unlike the gll* forks that were seeded from a
release.

**This is the single most important difference from `glldzlib`.** That fork is an
SVN snapshot with no shared history, so mass edits there cost nothing. Here every
edit to an upstream file is a conflict on some future merge. Keep changes
minimal, targeted, and recorded in `CHANGELOG.md`.

### The pre-D13 package folders stay

`Packages/Berlin`, `Tokyo`, `Rio` and `Sydney` are pre-D13 and build nothing
here. Do **not** delete them. Checked 2026-08-28: upstream still ships all four,
15 files each, and last touched them on 2026-06-05. Removing them buys 60 dead
files and costs a conflict every time upstream touches them again.

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
