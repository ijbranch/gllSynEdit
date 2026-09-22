{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Tests for word navigation - NextWordPosEx and PrevWordPosEx, the engines behind
Ctrl+Right, Ctrl+Left and the word-delete commands.

WHY THIS FILE EXISTS. Upstream 22d9ea0 switched those six call sites from
IsIdentChar to the new IsWordChar. That is a deliberate BEHAVIOUR CHANGE rather
than a defect fix - no defect report accompanies it, and the commit message says
only "Used the new method IsWordChar" - so it arrived with nothing pinning it.
It also lands exactly where this estate actually uses SynEdit: the one real
consumer, DBiReportsScanEdit, sets NO highlighter, which is precisely the branch
these tests exercise.

WHAT ACTUALLY CHANGED, with no highlighter assigned:
  IsIdentChar(c) = c is '_' or a letter or a digit
  IsWordChar(c)  = c is neither a word BREAK char nor white space
The two disagree for any character that is none of those things and is also
absent from the break list - a currency sign, a copyright sign, an em dash, a
curly quote. Those used to terminate a word and now continue one. Characters in
the break list ('-', '.', '(' ...) are unaffected, and so are letters, digits
and spaces; the tests below assert both halves, because a change that quietly
widened to everything would be a different bug.
-------------------------------------------------------------------------------}

unit TestWordNavigation;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Word movement over text with no highlighter assigned.</summary>
  [TestFixture]
  TWordNavigationTests = class
  public
    /// <summary>
    ///   The ordinary case must be untouched: over plain words separated by
    ///   spaces, Ctrl+Right lands on the start of the next word. Without this
    ///   the widened rule could swallow whole lines and the tests below would
    ///   still pass.
    /// </summary>
    [Test] procedure NextWordPos_OverPlainWords_IsUnchanged;
    /// <summary>
    ///   Characters that are word BREAKS stay breaks. '-' and '.' are in the
    ///   break list, so they must still end a word - IsWordChar is wider than
    ///   IsIdentChar, not unconditional.
    /// </summary>
    [Test] procedure NextWordPos_BreakCharactersStillBreak;
    /// <summary>
    ///   THE BEHAVIOUR CHANGE, stated directly: a non-ASCII symbol that is
    ///   neither an identifier character nor a declared break - here the pound
    ///   sign - now CONTINUES a word instead of ending one.
    /// </summary>
    [Test] procedure NextWordPos_NonBreakSymbolNowContinuesTheWord;
    /// <summary>The same rule applies going backwards, or Ctrl+Left and
    ///   Ctrl+Right would disagree about where a word starts.</summary>
    [Test] procedure PrevWordPos_NonBreakSymbolNowContinuesTheWord;
    /// <summary>White space is not a word character, whatever else changed -
    ///   the guard against IsWordChar becoming "always true".</summary>
    [Test] procedure WhiteSpaceIsNeverAWordCharacter;
  end;

implementation

uses
  System.SysUtils,
  SynEdit,
  SynEditTypes;

type
  /// <summary>Publishes the protected classifier so the rule can be asserted
  ///  directly, not only through the movement commands.</summary>
  TWordCharProbe = class(TSynEdit)
  public
    /// <summary>True when AChar continues a word.</summary>
    /// <param name="AChar">The character to classify.</param>
    /// <returns>TCustomSynEdit.IsWordChar's answer.</returns>
    function WordChar(AChar: WideChar): Boolean;
  end;

function TWordCharProbe.WordChar(AChar: WideChar): Boolean;
begin
  Result := IsWordChar(AChar);
end;

// A TSynEdit with no parent and no highlighter, holding one line. Nothing here
// needs a window handle: NextWordPosEx and PrevWordPosEx are pure over Lines.
function MakeEditor(const AText: string): TWordCharProbe;
begin
  Result := TWordCharProbe.Create(nil);
  Result.Highlighter := nil;
  Result.Lines.Text := AText;
end;

function BC(AChar, ALine: Integer): TBufferCoord;
begin
  Result.Char := AChar;
  Result.Line := ALine;
end;

{ TWordNavigationTests }

procedure TWordNavigationTests.NextWordPos_OverPlainWords_IsUnchanged;
var
  Ed: TWordCharProbe;
begin
  //            1234567890
  Ed := MakeEditor('alpha beta');
  try
    Assert.AreEqual(7, Integer(Ed.NextWordPosEx(BC(1, 1)).Char),
      'from the start of "alpha" the next word begins at "beta"');
  finally
    Ed.Free;
  end;
end;

procedure TWordNavigationTests.NextWordPos_BreakCharactersStillBreak;
var
  Ed: TWordCharProbe;
begin
  Ed := MakeEditor('a-b.c');
  try
    // Both are in the default word-break list, so IsWordChar must refuse them
    // even though it is wider than IsIdentChar. If the widening had been
    // unconditional, 'a-b.c' would be one word and every assertion above
    // would still have passed.
    Assert.IsFalse(Ed.WordChar('-'), 'the hyphen is a declared word break');
    Assert.IsFalse(Ed.WordChar('.'), 'and so is the full stop');
    Assert.AreEqual(2, Integer(Ed.NextWordPosEx(BC(1, 1)).Char),
      'the word "a" ends at the hyphen');
  finally
    Ed.Free;
  end;
end;

procedure TWordNavigationTests.NextWordPos_NonBreakSymbolNowContinuesTheWord;
var
  Ed: TWordCharProbe;
begin
  Ed := MakeEditor('a' + #$00A3 + 'b end');
  try
    // Before 22d9ea0 the pound sign was not an identifier character, so the
    // word ended at it; now it continues one, and the whole 'a£b' is a word.
    Assert.IsTrue(Ed.WordChar(#$00A3),
      'the pound sign is neither a break character nor white space');
    Assert.AreEqual(5, Integer(Ed.NextWordPosEx(BC(1, 1)).Char),
      'the word runs through the pound sign to the space, then skips it');
  finally
    Ed.Free;
  end;
end;

procedure TWordNavigationTests.PrevWordPos_NonBreakSymbolNowContinuesTheWord;
var
  Ed: TWordCharProbe;
begin
  Ed := MakeEditor('a' + #$00A3 + 'b end');
  try
    Assert.AreEqual(1, Integer(Ed.PrevWordPosEx(BC(4, 1)).Char),
      'going back from the space lands at the start of "a' + #$00A3 + 'b", not inside it');
  finally
    Ed.Free;
  end;
end;

procedure TWordNavigationTests.WhiteSpaceIsNeverAWordCharacter;
var
  Ed: TWordCharProbe;
begin
  Ed := MakeEditor('x y');
  try
    Assert.IsFalse(Ed.WordChar(' '), 'a space must never count as part of a word');
    Assert.IsFalse(Ed.WordChar(#9), 'nor a tab');
    Assert.IsTrue(Ed.WordChar('x'), 'but an ordinary letter must');
    Assert.IsTrue(Ed.WordChar('7'), 'and a digit');
  finally
    Ed.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWordNavigationTests);

end.
