{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Contract tests for every registered SynEdit highlighter.

These assert the invariants that the scanning loop "while not GetEol do Next"
depends on, against every class in GetPlaceableHighlighters, with no per-language
knowledge. They exist because the defects they catch are invisible to a build:
a highlighter that fails them still compiles, and the symptom is a frozen editor
or wrong colours far from the cause.
-------------------------------------------------------------------------------}

unit TestHighlighterContract;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  THighlighterContractTests = class
  public
    /// <summary>
    ///   Constructing every registered highlighter must not corrupt memory.
    ///   A keyword hash that indexes its dispatch table out of bounds does its
    ///   damage in the constructor, before any file is ever opened.
    /// </summary>
    [Test]
    procedure ConstructionIsClean;
    /// <summary>
    ///   Next must consume at least one character or reach end of line, for
    ///   every highlighter and every probe line. A token procedure that returns
    ///   without advancing Run spins the scanning loop for ever.
    /// </summary>
    [Test]
    procedure NextAlwaysAdvances;
    /// <summary>
    ///   GetRange must round-trip through SetRange. Any scanner state that is
    ///   not carried by the range pointer is lost when SynEdit repaints from
    ///   the middle of a document.
    /// </summary>
    [Test]
    procedure RangeRoundTrips;
    /// <summary>
    ///   Scanning a highlighter's own SampleSource from a restored range must
    ///   produce the same tokens as scanning it sequentially. This is the
    ///   "repaint starts mid-document" case that a range round-trip alone does
    ///   not prove.
    /// </summary>
    [Test]
    procedure SampleSourceScansIdenticallyFromARestoredRange;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  SynEditHighlighter,
  SynEditTypes,
  SynFunc;

const
  /// Probe lines. Every one of these has broken at least one highlighter.
  ProbeLines: array [0 .. 19] of string = (
    '',                       ' ',                       #9,
    '!',                      '!imp',                    '@',
    '<',                      '"',                       '''',
    '''''''',                 '#',                       '$',
    '\',                      'q',                       '%=',
    'a' + #$00DF + 'b',       '/*',                      '*/',
    '[',                      '`'
  );

  /// Far above any legitimate token count for a line of this length.
  MaxTokensPerLine = 4096;

{ THighlighterContractTests }

procedure THighlighterContractTests.ConstructionIsClean;
var
  HLClass: TSynCustomHighlighterClass;
  HL: TSynCustomHighlighter;
begin
  Assert.IsTrue(GetPlaceableHighlighters.Count > 0,
    'No highlighters are registered - check that the units are linked in.');

  for HLClass in GetPlaceableHighlighters do
  begin
    HL := HLClass.Create(nil);
    try
      Assert.IsNotEmpty(HLClass.GetLanguageName,
        HLClass.ClassName + '.GetLanguageName is empty');
      Assert.IsNotEmpty(HLClass.GetFriendlyLanguageName,
        HLClass.ClassName + '.GetFriendlyLanguageName is empty');
    finally
      HL.Free;
    end;
  end;
end;

procedure THighlighterContractTests.NextAlwaysAdvances;
var
  HLClass: TSynCustomHighlighterClass;
  HL: TSynCustomHighlighter;
  Probe: string;
  Tokens: Integer;
  PrevPos: TSynNativeInt;
begin
  for HLClass in GetPlaceableHighlighters do
  begin
    HL := HLClass.Create(nil);
    try
      for Probe in ProbeLines do
      begin
        HL.ResetRange;
        HL.SetLine(Probe, 1);

        Tokens := 0;
        PrevPos := -1;
        while not HL.GetEol do
        begin
          Assert.IsTrue(HL.GetTokenPos > PrevPos,
            Format('%s did not advance at position %d of %s',
              [HLClass.ClassName, HL.GetTokenPos, QuotedStr(Probe)]));
          PrevPos := HL.GetTokenPos;

          HL.Next;
          Inc(Tokens);
          Assert.IsTrue(Tokens < MaxTokensPerLine,
            Format('%s produced %d tokens for %s - the scanner is not terminating',
              [HLClass.ClassName, Tokens, QuotedStr(Probe)]));
        end;
      end;
    finally
      HL.Free;
    end;
  end;
end;

procedure THighlighterContractTests.RangeRoundTrips;
var
  HLClass: TSynCustomHighlighterClass;
  HL: TSynCustomHighlighter;
  Probe: string;
  SavedRange: Pointer;
begin
  for HLClass in GetPlaceableHighlighters do
  begin
    HL := HLClass.Create(nil);
    try
      for Probe in ProbeLines do
      begin
        HL.ResetRange;
        HL.SetLine(Probe, 1);
        HL.NextToEol;

        SavedRange := HL.GetRange;
        HL.SetRange(SavedRange);
        Assert.AreEqual(NativeInt(SavedRange), NativeInt(HL.GetRange),
          HLClass.ClassName + '.GetRange/SetRange does not round-trip after ' +
          QuotedStr(Probe));
      end;
    finally
      HL.Free;
    end;
  end;
end;

procedure THighlighterContractTests.SampleSourceScansIdenticallyFromARestoredRange;

  /// Scans every line of Lines and returns "kind:token" for each token. When
  /// RestoreEachLine is set, the range is saved and restored around every line,
  /// which is what SynEdit does when it repaints starting part-way down.
  function Scan(HL: TSynCustomHighlighter; Lines: TStrings;
    RestoreEachLine: Boolean): string;
  var
    I: Integer;
    SB: TStringBuilder;
    Range: Pointer;
  begin
    SB := TStringBuilder.Create;
    try
      HL.ResetRange;
      for I := 0 to Lines.Count - 1 do
      begin
        if RestoreEachLine then
        begin
          Range := HL.GetRange;
          HL.SetRange(Range);
        end;
        HL.SetLine(Lines[I], I + 1);
        while not HL.GetEol do
        begin
          SB.Append(HL.GetTokenKind).Append(':').Append(HL.GetToken).Append('|');
          HL.Next;
        end;
        SB.AppendLine;
      end;
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end;

var
  HLClass: TSynCustomHighlighterClass;
  HL: TSynCustomHighlighter;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    for HLClass in GetPlaceableHighlighters do
    begin
      HL := HLClass.Create(nil);
      try
        Lines.Text := HL.SampleSource;
        if Lines.Count = 0 then
          Continue;
        Assert.AreEqual(Scan(HL, Lines, False), Scan(HL, Lines, True),
          HLClass.ClassName + ' scans its own SampleSource differently when the ' +
          'range is restored per line - some scanner state is not carried by GetRange');
      finally
        HL.Free;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THighlighterContractTests);

end.
