# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> The change record of the `SynEditTests` test suite (`Tests`).  Kept beside the suite since
> 2026-10-25 (Ian: "every test suite should have its own change log"); test-only entries recorded before that in
> the repository's `CHANGELOG.md` were moved here the same day.  Product changes, including those that change a
> product unit together with its tests, stay in the repository's `CHANGELOG.md`.

## [In-Service]

### Added

- (2026-11-07) **Upstream intake to `3d03c98`: 8 tests, and `TSynAsmX86_64` linked into the contract tests** — `TestAsmX86_64.pas` (new), `TestEditorColours.pas` (new), `SynEditTests.dpr`, `SynEditTests.dproj`, `README.md`.  Suite 15 -> 23 (22 pass, 1 ignored off an interactive station).  `TestEditorColours` paints an editor on a never-shown form into a bitmap and asserts what `OnSpecialLineColors` receives (unstyled; the styled case needs visual styles and ignores itself via `GllDUnitX.Station.RequireInteractiveStation`, hence `D:\gllDUnitX\Source\Gll` on the unit path) and the gutter `DigitCount` range; `TestAsmX86_64` checks token classes on x86-64 and AVX lines.  Red first: linking the new highlighter turned three contract tests and three new tests into access violations, and the keyword tests failed on the missing commas; both mutation proofs and the fixes are in `..\CHANGELOG.md`.  `README.md` (new) lists the ignored-by-design test; `SynEditTests.dproj` is now CRLF throughout (it was LF-only, unflagged because the file is `-text` to git).  Upstream's `TestSynEditStringList.pas` was not taken (duplicate of `TestTextBuffer`).
- (2026-10-25) **This change log** — `CHANGELOG.md`.  The suite's own record, per the estate rule that every test
  suite has one; test-only history moved in from `..\CHANGELOG.md` ( 4 entries ).
- (2026-09-23) **Five tests pinning word navigation, which had none**
  - `Tests/TestWordNavigation.pas` (new), `Tests/SynEditTests.dpr`
  Suite 7 -> 12, all green. They exist because the `IsWordChar` change below is a
  deliberate BEHAVIOUR CHANGE rather than a defect fix, and it arrived with nothing
  pinning it - upstream cites no defect and the commit message says only "Used the new
  method IsWordChar". It also lands exactly where this estate really uses SynEdit: the
  one real consumer, `DBiReportsScanEdit`, sets **no highlighter**, which is the branch
  these tests exercise.
  Both halves are asserted on purpose. A widening that had gone too far - making every
  character a word character - would pass a test that only checked the pound sign, so
  `NextWordPos_BreakCharactersStillBreak` and `WhiteSpaceIsNeverAWordCharacter` pin the
  other side.
  **Mutation-proved:** putting `NextWordPosEx` back on `IsIdentChar` gives
  `Expected [5] but got [2]` - the word stops dead at the pound sign.

### Changed

- (2026-10-18) **The test runner honours DUnitX's own command-line options, above all `--run:<names>`** - `Tests/SynEditTests.dpr`.  It now calls `TDUnitX.CheckCommandLine` before creating the runner, so GITLAKMCP's `test_run` can run a single fixture or test.  An unknown option is now the caller's error and exits 251 instead of being ignored.  A run of zero tests (a filter matching nothing) now exits 250 rather than 0, so an empty run can no longer read as a pass.  A no-argument run is unchanged.

### Fixed

- (2026-10-18) **A crash outside the tests made the test runner exit 0, which reads as a green run.**  The outer `except` printed the exception and left the exit code alone; it now sets 2, as the other suites do. — `Tests\SynEditTests.dpr`
- (2026-09-20) **Registered with the estate test runner - 7 tests nothing was running**
  - `Tests/SynEditTests.dpr`
  The suite passed 7/7 and no automated runner executed it; it only ran if someone
  launched the exe by hand. Found by listing every test project on disk and diffing against
  the `[TestRunner]` targets in GITLAKMCP's `settings.ini`.
  It could not simply be added. It wrote DUnitX's default `dunitx-results.xml`, and the
  runner looks for `<exeDir>\<exeBaseName>-results.xml`, reporting `status: error` with an
  ALL-ZERO summary on anything else - which reads like a broken suite rather than a misnamed
  file, and is why this was never chased. Now falls back to the convention while still
  honouring an explicit `--xmloutput`.
  `Runner.UseRTTI := False` was also corrected to `True`. The comment justifying it said RTTI
  would find the fixtures twice and run every test twice - it does NOT: our `gllDUnitX` fork
  dedupes a fixture registered both ways, and turning the flag OFF is what silently deletes
  tests (measured 2026-09-18: 414 -> 380, exit 0). **Verified**: still exactly 7 tests.
  Registered as `Target24`; `test_run` reports 7/7, and the count is unchanged by the fix.
