{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Tests for TSynAsmX86_64, the x86-64 / AVX highlighter taken from upstream
9981b7b + dc94afa on 2026-11-07.

TestHighlighterContract already holds it to the scanning contract that every
highlighter meets.  These tests check that it classifies real x86-64 and AVX
lines sensibly, and pin the two defects found in the upstream unit on intake:

  - Seven keyword lists ran two entries together where a comma was missing
    between concatenated string literals ('xmm31' + 'ymm0' became 'xmm31ymm0'),
    so ymm0, zmm0, vaddpd, int3 and others were never recognised.
  - IsLabel cast Owner to TSynEdit without checking it, so any non-keyword
    identifier raised an access violation when the highlighter was owned by
    nil (as here) or by a form (as when dropped at design time).
-------------------------------------------------------------------------------}

unit TestAsmX86_64;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Token classification by TSynAsmX86_64.</summary>
  [TestFixture]
  TAsmX86_64Tests = class
  public
    /// <summary>
    ///   Proves a general-purpose line tokenises as an assembler programmer
    ///   expects: mnemonic, registers, size keywords, brackets, operator and
    ///   number each get their own class, and the comment runs to end of line.
    /// </summary>
    [Test] procedure GeneralPurposeLine_IsClassified;
    /// <summary>
    ///   Proves AVX mnemonics and the vector registers are recognised, including
    ///   the entries that sat next to a missing comma in upstream's lists
    ///   (vaddpd, ymm0, ymm31, zmm0, zmm15, zmm16, xmm31).  Before the fix
    ///   these were plain identifiers.
    /// </summary>
    [Test] procedure AvxLine_RecognisesEveryVectorRegister;
    /// <summary>
    ///   Proves the other entries at a missing comma are keywords again (int3,
    ///   addsubpd, vmovw, vpsravq, vaddsubpd), that the lists are matched
    ///   case-insensitively, and that vtestpd / vtestps stay AVX: the general
    ///   mnemonic list's run-together "vtestpdvtestps" is deliberately left
    ///   alone, because splitting it would give those two the first-inserted
    ///   (plain keyword) class instead.
    /// </summary>
    [Test] procedure EntriesAtFormerMissingCommas_AreKeywords;
    /// <summary>
    ///   Proves jumps, conditional moves and hexadecimal literals get their own
    ///   classes, and that a non-keyword identifier with the highlighter owned
    ///   by nil is an identifier rather than an access violation in IsLabel.
    /// </summary>
    [Test] procedure JumpConditionalHex_AndUnownedIdentifier;
    /// <summary>
    ///   Proves label lookup where it can work (owned by a TSynEdit): an indented
    ///   "done:" followed by a comment makes "done" a label in "jmp done ; again"
    ///   (upstream compared the rest of the line, so neither matched), a prefix
    ///   ("don") is not one, and a colon after an identifier is a declaration
    ///   while a separator with no identifier before it is a symbol.
    /// </summary>
    [Test] procedure LabelDeclaredInOwningEditor_IsALabel;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  SynEdit,
  SynHighlighterAsmX86_64;

type
  /// <summary>One token: its text and its kind.</summary>
  TTok = record
    /// <summary>The token text.</summary>
    Text: string;
    /// <summary>The highlighter's token kind.</summary>
    Kind: TtkTokenKind;
  end;

// Scans one line and returns every token that is not white space.
function Scan(AHL: TSynAsmX86_64; const ALine: string): TArray<TTok>;
var
  List: TList<TTok>;
  Tok: TTok;
begin
  List := TList<TTok>.Create;
  try
    AHL.ResetRange;
    AHL.SetLine(ALine, 1);
    while not AHL.GetEol do
    begin
      if AHL.GetTokenID <> tkSpace then
      begin
        Tok.Text := AHL.GetToken;
        Tok.Kind := AHL.GetTokenID;
        List.Add(Tok);
      end;
      AHL.Next;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function KindName(AKind: TtkTokenKind): string;
const
  CNames: array[TtkTokenKind] of string = ('Comment', 'Identifier', 'Key', 'Null', 'Number', 'Space', 'String',
    'Symbol', 'Bracket', 'Math', 'Unknown', 'Register', 'FloatRegister', 'TypeSize', 'Jump', 'Conditional', 'AVX',
    'LabelDeclaration', 'Label', 'Char', 'Float', 'Hex', 'Octal');
begin
  Result := CNames[AKind];
end;

// Asserts the line yields exactly these tokens with these kinds.
procedure ExpectTokens(AHL: TSynAsmX86_64; const ALine: string; const ATexts: array of string;
  const AKinds: array of TtkTokenKind);
var
  Toks: TArray<TTok>;
  I: Integer;
begin
  Toks := Scan(AHL, ALine);
  Assert.AreEqual(Length(ATexts), Length(Toks), Format('token count in "%s"', [ALine]));
  for I := 0 to High(Toks) do
  begin
    Assert.AreEqual(ATexts[I], Toks[I].Text, Format('token %d of "%s"', [I, ALine]));
    Assert.AreEqual(KindName(AKinds[I]), KindName(Toks[I].Kind), Format('kind of "%s" in "%s"', [Toks[I].Text, ALine]));
  end;
end;

{ TAsmX86_64Tests }

procedure TAsmX86_64Tests.GeneralPurposeLine_IsClassified;
var
  HL: TSynAsmX86_64;
begin
  HL := TSynAsmX86_64.Create(nil);
  try
    ExpectTokens(HL, 'mov rax, qword ptr [rbx+8] ; load',
      ['mov', 'rax', ',', 'qword', 'ptr', '[', 'rbx', '+', '8', ']', '; load'],
      [tkKey, tkRegister, tkSymbol, tkTypeSize, tkTypeSize, tkBracket, tkRegister, tkMath, tkNumber, tkBracket,
       tkComment]);
  finally
    HL.Free;
  end;
end;

procedure TAsmX86_64Tests.AvxLine_RecognisesEveryVectorRegister;
var
  HL: TSynAsmX86_64;
begin
  HL := TSynAsmX86_64.Create(nil);
  try
    ExpectTokens(HL, 'vaddps ymm0, ymm1, ymm31',
      ['vaddps', 'ymm0', ',', 'ymm1', ',', 'ymm31'],
      [tkAVX, tkFloatRegister, tkSymbol, tkFloatRegister, tkSymbol, tkFloatRegister]);
    ExpectTokens(HL, 'vaddpd zmm0, zmm15, zmm16',
      ['vaddpd', 'zmm0', ',', 'zmm15', ',', 'zmm16'],
      [tkAVX, tkFloatRegister, tkSymbol, tkFloatRegister, tkSymbol, tkFloatRegister]);
    ExpectTokens(HL, 'vxorps xmm0, xmm0, xmm31',
      ['vxorps', 'xmm0', ',', 'xmm0', ',', 'xmm31'],
      [tkAVX, tkFloatRegister, tkSymbol, tkFloatRegister, tkSymbol, tkFloatRegister]);
  finally
    HL.Free;
  end;
end;

procedure TAsmX86_64Tests.EntriesAtFormerMissingCommas_AreKeywords;
var
  HL: TSynAsmX86_64;
begin
  HL := TSynAsmX86_64.Create(nil);
  try
    ExpectTokens(HL, 'int3', ['int3'], [tkKey]);
    ExpectTokens(HL, 'ADDSUBPD', ['ADDSUBPD'], [tkKey]);
    ExpectTokens(HL, 'vmovw', ['vmovw'], [tkAVX]);
    ExpectTokens(HL, 'vpsravq', ['vpsravq'], [tkAVX]);
    ExpectTokens(HL, 'vaddsubpd', ['vaddsubpd'], [tkAVX]);
    ExpectTokens(HL, 'vtestpd', ['vtestpd'], [tkAVX]);
    ExpectTokens(HL, 'vtestps', ['vtestps'], [tkAVX]);
  finally
    HL.Free;
  end;
end;

procedure TAsmX86_64Tests.JumpConditionalHex_AndUnownedIdentifier;
var
  HL: TSynAsmX86_64;
begin
  HL := TSynAsmX86_64.Create(nil);
  try
    ExpectTokens(HL, 'cmovne eax, 0x1F', ['cmovne', 'eax', ',', '0x1F'], [tkConditional, tkRegister, tkSymbol, tkHex]);
    ExpectTokens(HL, 'jne done', ['jne', 'done'], [tkJump, tkIdentifier]);
  finally
    HL.Free;
  end;
end;

procedure TAsmX86_64Tests.LabelDeclaredInOwningEditor_IsALabel;
var
  Ed: TSynEdit;
  HL: TSynAsmX86_64;
begin
  Ed := TSynEdit.Create(nil);
  try
    HL := TSynAsmX86_64.Create(Ed);
    Ed.Lines.Text := 'jmp done ; again'#13#10'  done: ; the end'#13#10'ret'#13#10'  doneX:';
    ExpectTokens(HL, 'jmp done ; again', ['jmp', 'done', '; again'], [tkJump, tkLabel, tkComment]);
    ExpectTokens(HL, 'jmp elsewhere', ['jmp', 'elsewhere'], [tkJump, tkIdentifier]);
    // "done:" does not declare its prefix "don": the match is the whole identifier.
    ExpectTokens(HL, 'jmp don', ['jmp', 'don'], [tkJump, tkIdentifier]);
    ExpectTokens(HL, 'done:', ['done', ':'], [tkLabel, tkLabelDeclaration]);
    // A separator with no identifier before it on its own line is a symbol.
    ExpectTokens(HL, ', 1', [',', '1'], [tkSymbol, tkNumber]);
  finally
    Ed.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAsmX86_64Tests);

end.
