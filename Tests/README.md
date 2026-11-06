# SynEditTests

The DUnitX suite of the gllSynEdit fork.  Change record: `CHANGELOG.md` beside this file.

## Ignored by design

- `TEditorColourTests.SpecialLineColors_SeededFromStyleWhenStyled` ignores itself on a non-interactive window station
  (GITLAKMCP's service, where `test_run` runs it): a VCL style needs visual styles, which that station does not have.
  It also ignores itself when the Aqua Light Slate style file is not installed.  Run the exe from a desktop to exercise it.

## Known bugs pinned

None.
