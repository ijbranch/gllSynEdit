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
    /// <summary>The list under test; typed TObject so the interface needs no SynEdit unit.</summary>
    FLines: TObject;
    /// <summary>Thread that ran the test, against which MeasureLength classifies its callers.</summary>
    FTestThreadId: TThreadID;
    /// <summary>Number of MeasureLength calls made on any other thread (updated atomically).</summary>
    FOffThreadCalls: Integer;
    /// <summary>When True, MeasureLength raises on the Poison line instead of measuring it.</summary>
    FRaiseOnPoison: Boolean;
    /// <summary>Text-width function for the MaxWidth tests: the string's length, noting off-thread calls.</summary>
    /// <param name="S">Line text to measure.</param>
    /// <returns>Length of S.</returns>
    function MeasureLength(const S: string): NativeInt;
    /// <summary>Builds a list measured by MeasureLength whose longest line is the given index.</summary>
    /// <param name="ALines">Number of lines to add.</param>
    /// <param name="ALongest">Index of the one line made longer than the rest.</param>
    /// <returns>A new list, owned by the caller.</returns>
    function NewMeasuredList(ALines, ALongest: Integer): TObject;
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
    /// <summary>
    ///   MaxWidth finds the longest line in an ordinary process, and (on more than one
    ///   core) proves the TParallel.For path really ran by seeing a pool thread measure.
    /// </summary>
    [Test]
    procedure MaxWidthFindsTheLongestLine;
    /// <summary>
    ///   Inside a DLL (IsLibrary) MaxWidth must measure every line on the calling thread:
    ///   TThreadPool.Default cannot be shut down cleanly on DLL unload under the loader
    ///   lock, so starting its workers from a DLL hangs or crashes the unload (upstream
    ///   09855c5).  Proves both the result and that no worker thread measured a line.
    /// </summary>
    [Test]
    procedure MaxWidthInALibraryStaysOnTheCallingThread;
    /// <summary>
    ///   A width function that raises part-way must not leave the partial maximum
    ///   cached: the FMaxWidth &gt; 0 shortcut would return it from then on, so the
    ///   editor's horizontal extent would stay short of the longest line.  Run in
    ///   library mode, whose sequential order makes the partial maximum certain.
    /// </summary>
    [Test]
    procedure MaxWidthIsNotCachedAfterAMeasureRaises;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
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

const
  // Enough lines that TParallel.For hands work to pool threads on any multi-core machine.
  MeasuredLines = 20000;
  MeasuredLongest = 12345;
  // The line on which MeasureLength raises while FRaiseOnPoison is set (index 100,
  // well before MeasuredLongest), and the exception it raises.
  PoisonLine = 100;
  PoisonMessage = 'width function failed';

function TSynEditStringListTests.MeasureLength(const S: string): NativeInt;
begin
  if TThread.CurrentThread.ThreadID <> FTestThreadId then
    TInterlocked.Increment(FOffThreadCalls);
  if FRaiseOnPoison and (S = 'poison') then
    raise Exception.Create(PoisonMessage);
  Result := Length(S);
end;

function TSynEditStringListTests.NewMeasuredList(ALines, ALongest: Integer): TObject;
var
  Lines: TSynEditStringList;
  I: Integer;
begin
  Lines := TSynEditStringList.Create(MeasureLength);
  try
    Lines.BeginUpdate;
    for I := 0 to ALines - 1 do
      if I = ALongest then
        Lines.Add(Marker + Marker)
      else
        Lines.Add(Marker);
    Lines.EndUpdate;
  except
    Lines.Free;
    raise;
  end;
  FTestThreadId := TThread.CurrentThread.ThreadID;
  FOffThreadCalls := 0;
  Result := Lines;
end;

procedure TSynEditStringListTests.MaxWidthFindsTheLongestLine;
var
  Lines: TSynEditStringList;
begin
  Lines := TSynEditStringList(NewMeasuredList(MeasuredLines, MeasuredLongest));
  try
    Assert.AreEqual(NativeInt(2 * Length(Marker)), Lines.MaxWidth, 'MaxWidth is not the longest line');
    // proves this ran the TParallel.For path; one core gives the pool nothing to add
    if TThread.ProcessorCount > 1 then
      Assert.IsTrue(FOffThreadCalls > 0, 'no line was measured on a pool thread: the parallel path did not run');
  finally
    Lines.Free;
  end;
end;

procedure TSynEditStringListTests.MaxWidthIsNotCachedAfterAMeasureRaises;
var
  Lines: TSynEditStringList;
  WasLibrary: Boolean;
  Raised: Boolean;
begin
  Lines := TSynEditStringList(NewMeasuredList(MeasuredLines, MeasuredLongest));
  WasLibrary := IsLibrary;
  try
    IsLibrary := True;   // sequential: lines 0..99 are measured, then line 100 raises
    Lines[PoisonLine] := 'poison';
    FRaiseOnPoison := True;
    Raised := False;
    try
      Assert.Fail('MaxWidth returned ' + IntToStr(Lines.MaxWidth) + ' instead of raising');
    except
      on E: Exception do
        Raised := E.Message = PoisonMessage;
    end;
    Assert.IsTrue(Raised, 'the width function''s exception did not reach the caller');
    FRaiseOnPoison := False;
    Assert.AreEqual(NativeInt(2 * Length(Marker)), Lines.MaxWidth,
      'MaxWidth returned the partial maximum cached before the exception');
  finally
    FRaiseOnPoison := False;
    IsLibrary := WasLibrary;
    Lines.Free;
  end;
end;

procedure TSynEditStringListTests.MaxWidthInALibraryStaysOnTheCallingThread;
var
  Lines: TSynEditStringList;
  WasLibrary: Boolean;
begin
  Lines := TSynEditStringList(NewMeasuredList(MeasuredLines, MeasuredLongest));
  WasLibrary := IsLibrary;
  try
    IsLibrary := True;   // what System sets when this code runs inside a DLL
    Assert.AreEqual(NativeInt(2 * Length(Marker)), Lines.MaxWidth, 'MaxWidth is not the longest line');
    Assert.AreEqual(0, FOffThreadCalls, 'lines were measured on thread-pool threads inside a library');
  finally
    IsLibrary := WasLibrary;
    Lines.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSynEditStringListTests);

end.
