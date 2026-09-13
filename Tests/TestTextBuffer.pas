{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Tests for TSynEditStringList, the non-visual core of the editor's text storage.
-------------------------------------------------------------------------------}

unit TestTextBuffer;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSynEditStringListTests = class
  private
    FLines: TObject;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///   A string still held by a caller must survive Delete followed by Clear.
    ///   Deleting used to leave an untracked bitwise copy of a live reference in
    ///   the vacated slot, which SetLength then released a second time.
    /// </summary>
    [Test]
    procedure DeleteThenClearDoesNotDoubleReleaseAHeldString;
    /// <summary>Same invariant for the multi-line DeleteLines path.</summary>
    [Test]
    procedure DeleteLinesThenClearDoesNotDoubleReleaseAHeldString;
    /// <summary>
    ///   Shrinking Capacity below Count must raise, not silently truncate the
    ///   backing array and leave every later index reading past its end.
    /// </summary>
    [Test]
    procedure CapacityBelowCountRaises;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  SynEditTextBuffer,
  SynFunc;

// TStrings.Strings is marked deprecated from Delphi 14 in favour of the Native
// accessors, but those are private here. The indexed property is the public API.
{$WARN SYMBOL_DEPRECATED OFF}

const
  // Long enough to defeat any small-string optimisation and distinctive enough
  // to be recognisable in a heap dump if this ever regresses.
  Marker = 'the-quick-brown-fox-jumps-over-the-lazy-dog-0123456789';

{ TSynEditStringListTests }

procedure TSynEditStringListTests.Setup;
begin
  FLines := TSynEditStringList.Create(nil);
end;

procedure TSynEditStringListTests.TearDown;
begin
  FLines.Free;
  FLines := nil;
end;

procedure TSynEditStringListTests.DeleteThenClearDoesNotDoubleReleaseAHeldString;
var
  Lines: TSynEditStringList;
  Held: string;
  I: Integer;
  Before: Integer;
begin
  Lines := TSynEditStringList(FLines);
  for I := 0 to 4 do
    Lines.Add(Marker + IntToStr(I));

  Held := Lines[Lines.CountNative - 1];   // the caller now shares the last line
  Lines.Delete(0);                        // shifts the tail down by one

  // The DELTA is the invariant, not the absolute count. Clearing the list must
  // release the one reference the list itself holds - no more. With the alias bug
  // the vacated slot held a second, uncounted copy of the same reference and
  // SetLength finalised it as well, so the drop was 2 and Held became a dangling
  // pointer into a freed block. Comparing the text would not reliably notice that;
  // the count does. (Measured: drop of 1 fixed, 2 mutated.)
  Before := StringRefCount(Held);
  Lines.Clear;                            // releases the whole backing array
  Assert.AreEqual(1, Before - StringRefCount(Held),
    'Clear released the held line more than once');
  Assert.AreEqual(Marker + '4', Held,
    'the held line did not survive Delete + Clear');
end;

procedure TSynEditStringListTests.DeleteLinesThenClearDoesNotDoubleReleaseAHeldString;
var
  Lines: TSynEditStringList;
  Held: string;
  I: Integer;
  Before: Integer;
begin
  Lines := TSynEditStringList(FLines);
  for I := 0 to 9 do
    Lines.Add(Marker + IntToStr(I));

  Held := Lines[Lines.CountNative - 1];
  Lines.DeleteLines(2, 3);

  // See DeleteThenClear...: the drop must be exactly one.
  Before := StringRefCount(Held);
  Lines.Clear;
  Assert.AreEqual(1, Before - StringRefCount(Held),
    'Clear released the held line more than once');
  Assert.AreEqual(Marker + '9', Held,
    'the held line did not survive DeleteLines + Clear');
end;

procedure TSynEditStringListTests.CapacityBelowCountRaises;
var
  Lines: TSynEditStringList;
  I: Integer;
  Raised: Boolean;
begin
  Lines := TSynEditStringList(FLines);
  for I := 0 to 4 do
    Lines.Add(Marker + IntToStr(I));

  Raised := False;
  try
    Lines.CapacityNative := 0;
  except
    on EListError do
      Raised := True;
  end;
  Assert.IsTrue(Raised, 'shrinking Capacity below Count must raise EListError');

  // The guard must also have left the list intact.
  Assert.AreEqual(5, Integer(Lines.CountNative), 'the list was modified anyway');
  Assert.AreEqual(Marker + '3', Lines[3], 'item 3 is no longer readable');
end;

initialization
  TDUnitX.RegisterTestFixture(TSynEditStringListTests);

end.
