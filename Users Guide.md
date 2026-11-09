# gllSynEdit — User's Guide

How to put a syntax-highlighting editor into a Delphi 13 VCL application with **gllSynEdit**, and how
to drive the parts of it people actually reach for: highlighters, code folding, search and replace,
multiple carets, squiggles, completion, spell checking, export and printing.

For a unit-by-unit map, the fork's scope and the error messages, see [Help.md](Help.md). For the
change record against upstream, `CHANGELOG.md`.

Everything below is Delphi 13 (RAD Studio 37.0), VCL, Win32 + Win64. Every example compiles against
the units in `Source\` and `Source\Highlighters\`.

---

## 1. Getting it into a project

There are two separate steps, and you probably need both.

### a) Install the design-time package, once

Build the runtime package first, then the design-time one — `SynEditDD` requires `SynEditDR`'s
`.dcp`, and the other order fails `E2225`:

```
build.cmd packages
```

Then install `Packages\11AndAbove\Delphi\SynEditDD.dproj` from **`bin64\bds.exe`**, the 64-bit IDE,
through **Component ▸ Install Packages ▸ Add**. Design packages register per IDE bitness, and a
package installed from the 32-bit IDE lands in a list the 64-bit IDE never reads — the symptom is not
a package error but `Error Reading Form: Class TSynEdit not found` when the designer streams a form.

Two palette pages appear: **SynEdit** (the editor, the exporters, the search engines, printing,
completion, macro recorder, spell check, auto-correct, options dialog, URI opener) and **SynEdit
Highlighters** (the highlighters that are registered on the palette: since 2026-11-09 every highlighter
the runtime package compiles, Go, Rust, Lua, TOML, PowerShell and WebStencils among them).

### b) Point your project at the compiled units

Consuming projects link the **Release DCUs**, not the source. Per platform:

| IDE setting | Value |
|---|---|
| Library path | `D:\gllSynEdit\37.0\<Platform>\Release` |
| Debug DCU path | `D:\gllSynEdit\37.0\<Platform>\Debug` |
| Browsing path | `D:\gllSynEdit\Source` and `D:\gllSynEdit\Source\Highlighters` |

Put `Source` on the **browsing** path, not the library path. Ctrl-click navigation still reaches the
source, but each project does not recompile the library into its own divergent DCU set.

Applications here link statically — no DBiWorkflow project sets `<UsePackages>true</UsePackages>` —
so **a fix in this library only reaches an application when that application is rebuilt.** Rebuilding
the packages is not enough, and it is easy to believe otherwise.

---

## 2. The smallest thing that works

Drop a `TSynEdit` on a form, or build one at runtime. This is a complete unit:

```pascal
unit MiniEditorFrm;

interface

uses
  System.Classes, Vcl.Forms, Vcl.Controls,
  SynEdit, SynEditHighlighter, SynHighlighterDelphi;

type
  TMiniEditorForm = class( TForm )
    procedure FormCreate( Sender: TObject );
  private
    FEditor      : TSynEdit;
    FHighlighter : TSynDelphiSyn;
  end;

implementation

{$R *.dfm}

procedure TMiniEditorForm.FormCreate( Sender: TObject );
begin
  FHighlighter := TSynDelphiSyn.Create( Self );

  FEditor             := TSynEdit.Create( Self );
  FEditor.Parent      := Self;
  FEditor.Align       := alClient;
  FEditor.Highlighter := FHighlighter;
  FEditor.Gutter.ShowLineNumbers := True;
  FEditor.Lines.Text  := 'procedure Hello;'#13#10'begin'#13#10'  Writeln( ''hi'' );'#13#10'end;';
end;

end.
```

`Lines` is a `TSynEditStringList` — a `TStrings`, so `LoadFromFile`, `SaveToFile`, `Assign` and
`Text` all work as you expect, and it additionally carries each line's highlighter range and
modification state.

The default `Options` are `SYNEDIT_DEFAULT_OPTIONS`, which is already a sensible editor:
`eoAutoIndent`, `eoDragDropEditing`, `eoKeepCaretX`, `eoEnhanceHomeKey`, `eoEnhanceEndKey`,
`eoTabIndent`, `eoTabsToSpaces`, `eoSmartTabDelete`, `eoGroupUndo`, `eoDropFiles`, `eoShowLigatures`,
`eoBracketsHighlight`, `eoAccessibility`, `eoCompleteBrackets`, `eoCompleteQuotes`. Scrolling is a
separate set, `ScrollOptions`, defaulting to `[eoHideShowScrollbars, eoDisableScrollArrows,
eoShowScrollHint]`.

---

## 3. Highlighters — the part you will actually configure

### Choosing one

A highlighter is a component you create, configure and assign to `Editor.Highlighter`. Assign `nil`
for plain text. 84 highlighter units ship; 82 of them register themselves on a global list at unit
initialization, and that list is how you write code that does not name every language.

```pascal
uses
  SynEditHighlighter;   // RegisterPlaceableHighlighter, GetPlaceableHighlighters

// What is available, without naming a single language:
for var LClass in GetPlaceableHighlighters do
  ListBox1.Items.Add( LClass.GetFriendlyLanguageName );  // 'Object Pascal', 'YAML', ...
```

`GetPlaceableHighlighters` returns a `TSynHighlighterList` — a `TList<TSynCustomHighlighterClass>`
with three lookups on it, each returning an index or -1:

```pascal
var LIndex := GetPlaceableHighlighters.FindByFriendlyName( 'YAML' );
var LOther := GetPlaceableHighlighters.FindByName( 'YAML' );        // GetLanguageName
var LThird := GetPlaceableHighlighters.FindByClass( SomeComponent );
```

To pick a highlighter by file extension you need **instances**, because `DefaultFilter` is an
instance property:

```pascal
function HighlighterForFile( AOwner: TComponent; const AFileName: string ): TSynCustomHighlighter;
begin
  Result := nil;
  var LExt := LowerCase( ExtractFileExt( AFileName ) );
  for var LClass in GetPlaceableHighlighters do
  begin
    var LCandidate := LClass.Create( AOwner );
    if Pos( '*' + LExt + ';', LCandidate.DefaultFilter + ';' ) > 0 then
      Exit( LCandidate );
    LCandidate.Free;
  end;
end;
```

`Demos\uHighlighterProcs.pas` does the same job for the demos — `GetHighlighters`,
`GetHighlightersFilter`, `GetHighlighterFromFileExt` — and is worth reading before writing your own.

### Colours and styles

Every highlighter publishes a set of `TSynHighlighterAttributes` — `KeyAttri`, `CommentAttri`,
`StringAttri`, `NumberAttri`, `SymbolAttri`, `IdentifierAttri` and whatever else the language needs.
You can reach them by name from the designer, or generically from code:

```pascal
for var I := 0 to Editor.Highlighter.AttrCount - 1 do
begin
  var LAttri := Editor.Highlighter.Attribute[ I ];
  LAttri.Background := clBlack;
  if LAttri.Name = 'Comment' then
    LAttri.Foreground := clGreen;
end;
```

Six attributes also have well-known aliases on the base class, for code that does not know the
language: `CommentAttribute`, `IdentifierAttribute`, `KeywordAttribute`, `StringAttribute`,
`SymbolAttribute`, `WhitespaceAttribute`.

A whole colour scheme round-trips through a file, the registry or an INI:

```pascal
Editor.Highlighter.SaveToFile( 'DarkScheme.ini' );
Editor.Highlighter.LoadFromFile( 'DarkScheme.ini' );
```

Wrap bulk changes in `BeginUpdate`/`EndUpdate` so the editor repaints once.

### Delphi source specifically

Use **`TSynDelphiSyn`** (`SynHighlighterDelphi`), not `TSynPasSyn`. It descends from
`TSynCustomCodeFoldingHighlighter`, knows the modern reserved words (`reference`, `helper`,
`operator`, `strict`, `sealed`, `final`, `delayed`), handles triple-quoted multiline strings, paints
`Integer`/`string`/`Boolean` and friends as data types through its own `DelphiTypes` list, and folds
`{$REGION}`, `implementation`, classes, records, methods and `begin`/`case`/`try` blocks.
`What's New.md` documents it and the design-time **Import IDE Settings** verb that copies your actual
IDE colours onto it.

### `TSynOmniSyn` — a highlighter you configure from a file

`TSynOmniSyn` is data-driven: keywords, comment styles, string rules, folding style and identifier
characters all come from an `.ini`. **189 language definitions ship** in
`Source\Highlighters\Omni Highlighters\`.

```pascal
uses
  SynHighlighterOmni;

var LOmni := TSynOmniSyn.Create( Self );
if LOmni.LoadFromIniFile( 'D:\gllSynEdit\Source\Highlighters\Omni Highlighters\Lua.ini' ) then
  Editor.Highlighter := LOmni;
```

Note the shadowing: `TSynOmniSyn.LoadFromIniFile` takes a **file name**, while the inherited
`TSynCustomHighlighter.LoadFromIniFile` takes a `TCustomIniFile`. `SaveToIniFile` is the same shape.
`TSynOmniSynSetup` (`SynOmniSetupDialog`) is a runtime editor for the whole definition.

### `TSynMultiSyn` — several languages in one document

`TSynMultiSyn` (`SynHighlighterMulti`) composes other highlighters into schemes delimited by regular
expressions — PHP inside HTML, script inside markup. It is the one highlighter unit that registers no
placeable highlighter of its own, because it has no language.

### Writing your own

Descend from `TSynCustomHighlighter` (or `TSynCustomCodeFoldingHighlighter` if it folds), and satisfy
the scanning contract in `Help.md` §3 — in particular, **end your `Next` with `inherited`**. That is
what arms the library's progress guard. Register it so it appears everywhere the others do:

```pascal
initialization
  RegisterPlaceableHighlighter( TMyLanguageSyn );
```

Then run `Tests\SynEditTests.dproj`: because `TestHighlighterContract` is data-driven over
`GetPlaceableHighlighters`, your highlighter is tested the moment it is linked in. Link the unit
explicitly in `SynEditTests.dpr` — a unit that is not linked registers nothing and is silently
skipped.

---

## 4. Code folding

Folding needs two things: a highlighter that can produce fold ranges, and the editor switched on.

```pascal
Editor.Highlighter    := TSynDelphiSyn.Create( Self );
Editor.UseCodeFolding := True;
Editor.CodeFolding.ShowCollapsedLine := True;
Editor.CodeFolding.CollapsedLineColor := clGrayText;
```

18 shipped highlighters descend from `TSynCustomCodeFoldingHighlighter` — among them Delphi, Object
Pascal, C++, C#, Java, JScript, PHP, Perl, Python, JSON, YAML, INI, VB, VBScript, Cobol, FoxPro, DWS
and Omni.

Programmatic control lives on the editor: `CollapseAll`, `UncollapseAll`, `CollapseNearest`,
`UncollapseNearest`, `CollapseLevel( N )`, `UnCollapseLevel( N )`, `CollapseFoldType( N )`,
`UncollapseAroundLine( Line )`, `SurfaceCaretFromHiddenFolds`, and `AllFoldRanges` for the ranges
themselves. The `ec*` commands (`ecFoldAll`, `ecUnfoldAll`, `ecFoldNearest`, `ecFoldLevel1`…,
`ecFoldRegions`…) are bound to customisable shortcuts.

For a language whose highlighter cannot fold, implement `Editor.OnScanForFoldRanges` instead — the
folding demo does exactly that for C++ files. `Doc/CodeFolding.md` is the design note; it names the
three calls a `ScanForFoldRanges` implementation makes: `FoldRanges.StartFoldRange`,
`FoldRanges.StopFoldRange`, `FoldRanges.NoFoldInfo`.

---

## 5. Search and replace

Assign a search engine, then call `SearchReplace`. Options come from `TSynSearchOptions`
(`SynEditTypes`): `ssoMatchCase`, `ssoWholeWord`, `ssoBackwards`, `ssoEntireScope`,
`ssoSelectedOnly`, `ssoReplace`, `ssoReplaceAll`, `ssoPrompt`.

```pascal
uses
  SynEditTypes, SynEditSearch, SynEditRegexSearch, SynEditWildcardSearch;

Editor.SearchEngine := TSynEditSearch.Create( Self );          // literal
// Editor.SearchEngine := TSynEditRegexSearch.Create( Self );  // PCRE
// Editor.SearchEngine := TSynEditWildcardSearch.Create( Self );  // * and ?

// Find the next occurrence from the caret:
if Editor.SearchReplace( 'TODO', '', [ ] ) = 0 then
  ShowMessage( 'Not found' );

// Replace throughout:
var LCount := Editor.SearchReplace( 'oldName', 'newName',
                                    [ ssoReplaceAll, ssoEntireScope, ssoMatchCase, ssoWholeWord ] );
```

`SearchReplace` has a second overload that takes explicit `Start` and `Stop` coordinates:

```pascal
function SearchReplace( const ASearch, AReplace: string; AOptions: TSynSearchOptions;
  const Start, Stop: TBufferCoord ): TSynNativeInt; overload;
```

With valid `Start` and `Stop` the search runs between those coordinates and `ssoSelection` and
`ssoEntireScope` are ignored. With `ssoSelection`, a valid `Start` and `Stop = TBufferCoord.Invalid`,
it runs **within the multiple selections**, after or before `Start` depending on `ssoBackwards`.
`Demos\SearchReplaceDemo` is maintained as the worked example of this.

`OnSearchNotFound` and `OnReplaceText` let you drive the UI. `SelectAllMatchingText` and
`SelectMatchingText` are the multi-caret side of search — see below.

---

## 6. Multiple carets and selections

This is built in; there is nothing to install. `Editor.Selections` is a `TSynSelections`, and
`Editor.Selection` is the active `TSynSelection` record.

Out of the box the user gets `Alt+Shift+Arrows` for column selection, `Ctrl+Shift+W`
(`ecSelMatchingText`) to add the next matching word to the selection, `Alt+End`
(`ecCaretsAtLineEnds`) to put a caret at the end of every selected line, and `Esc`
(`ecCancelSelections`) to drop back to one. `Ctrl+W` pressed repeatedly extends to following matches.

From code:

```pascal
uses
  SynEditMiscClasses;   // TSynSelection, TSynSelections, TSynSelStorage

// How many carets are live, and where is each one?
for var I := 0 to Editor.Selections.Count - 1 do
begin
  var LSel := Editor.Selections[ I ];
  Memo1.Lines.Add( Format( 'caret %d at line %d col %d',
                           [ I, LSel.Caret.Line, LSel.Caret.Char ] ) );
end;

// Save and restore ALL of them - CaretXY alone captures only the active one.
var LStorage: TSynSelStorage;
Editor.Selections.Store( LStorage );
// ... do something that moves the carets ...
Editor.Selections.Restore( LStorage );

Editor.SelectAllMatchingText;                 // a caret at every match of the current word
Editor.Selections.Clear( ksKeepActive );      // or ksKeepBase, as VS Code does
Editor.CaretsAtLineEnds;
```

Three rules worth memorising:

- **`ExecuteCommand` affects only the active selection.** `CommandProcessor` is the one that honours
  a command's `TSynCommandKind` and runs it once per caret.
- The old selection-mode API is gone: no `eoAltSetsColumnMode`, no `ecSelectNormal` /
  `ecSelectLine` / `ecSelectColumn`, and `UpdateCaret` is now `UpdateCarets`.
- Printing and print preview work on the active selection only.

`Doc/Multi-caret.md` is the full design note.

---

## 7. Squiggles and highlights — indicators

An indicator marks a span of text without changing the document: spelling squiggles, search hits,
compiler errors. You register a *spec* (how it looks) once per GUID, then add *indicators* (where it
applies) as often as you like.

```pascal
uses
  System.SysUtils, Vcl.Graphics, SynEditTypes, SynEditMiscClasses, SynDWrite;

const
  cSearchHitId: TGUID = '{4C0E7A61-8E5D-4F2B-9A7C-0B3D6E11F284}';

// Once, for the editor's lifetime:
var LSpec: TSynIndicatorSpec;
LSpec.Style      := sisTextDecoration;
LSpec.Background := D2D1ColorF( TColor( $0080FFFF ) );   // $00BBGGRR - pale yellow
LSpec.Foreground := D2D1ColorF( clBlack );
LSpec.FontStyle  := [ ];
Editor.Indicators.RegisterSpec( cSearchHitId, LSpec );

// Per hit - line is 1-based, character offsets are 1-based into that line:
Editor.Indicators.Add( LLine, TSynIndicator.New( cSearchHitId, LStart, LStart + LLength ), False );

// Afterwards, in one go:
Editor.Indicators.Clear( cSearchHitId );
```

`TSynIndicatorStyle` offers `sisTextDecoration`, `sisSquiggleMicrosoftWord`,
`sisSquiggleWordPerfect`, `sisRectangle`, `sisFilledRectangle`, `sisRoundedRectangle` and
`sisRoundedFilledRectangle`.

**Use `sisTextDecoration` when the text must stay readable.** The editor paints a text decoration
*before* the text layout and applies the foreground colour and font style to the matched run itself;
the filled-rectangle styles paint over finished text and hide it. That is measured behaviour, not a
preference.

Pass `Invalidate = False` while adding many indicators in a loop and repaint once at the end.
`IndicatorAtPos`, `IndicatorAtMousePos`, `LineIndicators` and `GetById` read them back — a hint
handler typically uses `IndicatorAtMousePos`. `TSynIndicator.KeepOnLineChange` keeps an indicator
alive across edits to its line, adjusting its offsets instead of dropping it.

---

## 8. Completion proposal and auto-correct

`TSynCompletionProposal` pops a list at the caret. Fill it in `OnExecute`:

```pascal
uses
  SynCompletionProposal;

procedure TForm1.ProposalExecute( Kind: SynCompletionType; Sender: TObject;
  var CurrentInput: string; var x, y: Integer; var CanExecute: Boolean );
begin
  Proposal.ItemList.Clear;
  Proposal.InsertList.Clear;
  Proposal.ItemList.Add( '\column{}procedure\column{}Hello' );
  Proposal.InsertList.Add( 'Hello' );
  CanExecute := Proposal.ItemList.Count > 0;
end;

// Setup:
Proposal.Editor        := Editor;
Proposal.ShortCut      := Vcl.Menus.ShortCut( Ord( ' ' ), [ ssCtrl ] );
Proposal.TriggerChars  := '.';
Proposal.TimerInterval := 1000;
Proposal.OnExecute     := ProposalExecute;
```

`ItemList` is what the user sees (with `\column{}` separators when you define `Columns`);
`InsertList` is what gets typed. `AddEditor`/`RemoveEditor` attach one proposal to several editors.
`TSynAutoComplete` is the simpler sibling — a plain expansion list with no callback.

`TSynAutoCorrect` (`SynAutoCorrect`) replaces as you type from an `Items` list of
`wrong<TAB>right` pairs, honouring `ascoIgnoreCase` and `ascoMaintainCase` by default:

```pascal
AutoCorrect.Editor := Editor;
AutoCorrect.Items.Add( 'teh' + #9 + 'the' );
```

---

## 9. Spell checking

`TSynSpellCheck` uses the **Windows `ISpellChecker` API** — no dictionary files to deploy, and the
languages are whatever Windows has:

```pascal
uses
  SynSpellCheck;

SpellCheck.Editor          := Editor;
SpellCheck.LanguageCode    := 'en-GB';        // defaults to the user locale
SpellCheck.CheckAsYouType  := True;
SpellCheck.PenColor        := clRed;
SpellCheck.UnderlineStyle  := usMicrosoftWord;
SpellCheck.CheckFile;

for var LLang in TSynSpellCheck.SupportedLanguages do
  cbLanguage.Items.Add( LLang );
```

**It is a singleton** — the constructor raises `ESynError` if one already exists. To cover more than
one editor, call `AddEditor` / `RemoveEditor` on the single instance.

`AttributesChecked` decides which token kinds are checked, defaulting to `Comment`, `Text`, `String`
and `Documentation` — so code is not spell-checked, prose is. `ErrorAtPos` returns the
`ISpellingError` at a coordinate, which is what a right-click menu needs. Eleven actions are
registered for the Action List editor under **SynEdit Spell Check** (`TSynSpellCheckFile`,
`TSynSpellCheckLine`, `TSynSpellCheckSelection`, `TSynSpellCheckWord`, `TSynSpellClearErrors`,
`TSynSpellCheckAsYouType`, and the `TSynSpellError*` family for replace/add/ignore/delete), so a
menu can be built without writing handlers.

---

## 10. Export and print

Export produces text in a foreign format, with the highlighting baked in:

```pascal
uses
  SynExportHTML;

var LExporter := TSynExporterHTML.Create( nil );
try
  LExporter.Title       := 'Listing';
  LExporter.Highlighter := Editor.Highlighter;
  LExporter.Font        := Editor.Font;
  LExporter.ExportAll( Editor.Lines );
  LExporter.SaveToFile( 'listing.html' );
finally
  LExporter.Free;
end;
```

`TSynExporterRTF` and `TSynExporterTeX` are the same shape. `ExportRange( Lines, Start, Stop )`
exports a span, `CopyToClipboard` puts it on the clipboard in the exporter's own format, and
`ExportedText` returns it as a string.

Printing:

```pascal
uses
  SynEditPrint;

Printer1.SynEdit       := Editor;     // takes Lines, Font and Highlighter from it
Printer1.Title         := 'Unit1.pas';
Printer1.Highlight     := True;
Printer1.Colors        := False;      // highlighting in black and white
Printer1.LineNumbers   := True;
Printer1.Wrap          := True;
Printer1.Header.Add( '$TITLE$', nil, taCenter, 1 );
Printer1.Footer.Add( 'Page $PAGENUM$ of $PAGECOUNT$', nil, taRight, 1 );
Printer1.Print;                        // or PrintRange( 1, 3 )
```

`TSynEditPrintPreview` is a control; set its `SynEditPrint` to the same component and call
`UpdatePreview`. `Demos\PrintDemo` shows both. `SelectedOnly` prints the selection.

---

## 11. Practical notes

- **Build both platforms, always.** `TSynNativeInt` is `NativeInt`, which *is* `Integer` on Win32, so
  a Win32-only build proves nothing. Eight of the twelve demos were broken on Win64 while all twelve
  built for Win32. Full explanation in `Help.md` §6.
- **Use `NativeInt` in new code**, not `TSynNativeInt`: on Delphi 13 they are the same type and it
  needs no extra `uses` entry.
- **Wrap bulk edits** in `Editor.BeginUpdate` / `EndUpdate`, and group undo with
  `BeginUndoBlock` / `EndUndoBlock` — every call must be matched, and a single undo then undoes the
  whole group. `Lines.BeginUpdate` calls through to the editor's.
- **`CutToClipboard` can now fail safely.** `OleSetClipboard` fails with `CLIPBRD_E_CANT_OPEN`
  whenever another process has the clipboard open — clipboard managers, RDP and VM clients, Office
  all hold it briefly. In this fork `CutToClipboard` deletes the selection **only on success**, and
  `TryCopyToClipboard: Boolean` is there when you need to act on the outcome.
- **Opening a binary file is cheap on purpose.** `AutoDetectBinary` is `True` by default and switches
  the editor into `BinaryMode`, where highlighting is skipped, widths are fixed and non-printable code
  points render as `.`. You can set `BinaryMode` yourself.
- **The editor is a VCL control on the main thread.** Scan or parse on a worker if you must, but touch
  `Lines`, `Selections` and `Indicators` from the main thread only.
- **A ready-made context menu.** Drop a `TSynPopupMenu` (unit `SynPopupMenu`) and assign it to the
  editor's `PopupMenu`. At run time it adds Undo, Redo, Cut, Copy, Paste, Delete and Select All as
  standard edit actions with their usual shortcuts. `DefaultPopupMenu` puts them before your own
  items (`dpmBefore`, the default), after them (`dpmAfter`) or nowhere (`dpmDisabled`), and
  `DefaultItems[meCopy]` and its siblings hand you each item to hide or re-caption. Nothing is added
  at design time, so the menu designer shows only your own items.
- **Recorded macro files are not portable across the fix.** The `TSynPositionEvent` format changed
  from `SizeOf(TBufferCoord)` (8 bytes on Win32, 16 on Win64) to fixed-width `Int64` fields;
  `TSynDataEvent` no longer persists its pointer at all. Old macro files will not load correctly.
- **`Demos\` is the reference.** Twelve projects, both platforms: `EditAppDemos` (SDI, MDI,
  workbook), `SimpleIDEDemo`, `HighlighterDemo`, `Folding`, `SearchReplaceDemo`,
  `CompletionProposalDemo` (plus `ParamCompletionDemo`), `PrintDemo`, `MarkdownViewer` and
  `SpellCheck`. They are the only consumers of the public API in the repository, which is why
  `build.cmd` builds them after any change to a public type.
