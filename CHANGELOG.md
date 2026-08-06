# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

GITLAK fork of TurboPack SynEdit (upstream `https://github.com/TurboPack/SynEdit`).
Scope: **Delphi 13+ / Win64 only**, installed into the 64-bit RAD Studio IDE. Upstream
content is unmodified except where entries below say otherwise, so the fork delta stays
visible.

## [Unreleased]

### Added

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
