{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Tests for two editor-level upstream fixes taken 2026-11-07:

  6e003a4  OnSpecialLineColors received FG and BG uninitialised. A handler that
           set only one of them left the other as whatever was on the stack,
           which in practice painted black. The colours are now seeded from
           Font.Color and Color (or the styled colours under an active VCL style)
           before the event is called.
  fe0545e  TSynGutter.DigitCount was clamped to 2..12; now 2..24, so a 16-digit
           hexadecimal offset fits the line-number band.

The colour tests paint the editor into an off-screen bitmap through PaintTo. The
editor sits on a form that is created but never shown, so nothing appears on
the desktop.
-------------------------------------------------------------------------------}

unit TestEditorColours;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>The colours OnSpecialLineColors is handed, and the gutter digit range.</summary>
  [TestFixture]
  TEditorColourTests = class
  public
    /// <summary>
    ///   Proves 6e003a4 with no VCL style active: on entry to OnSpecialLineColors
    ///   FG is the editor's Font.Color and BG its Color, on every line, including
    ///   the lines after one where the handler changed only one of the two. Before
    ///   the fix they were uninitialised locals, so a handler that set only BG
    ///   painted its text in whatever colour the stack held (in practice black).
    /// </summary>
    [Test] procedure SpecialLineColors_SeededFromFontAndColor;
    /// <summary>
    ///   Proves the styled half of 6e003a4: under an active VCL style the seeds
    ///   are the style's window-text and edit colours, not Font.Color and Color,
    ///   which a styled editor does not paint with.  Ignored on a non-interactive
    ///   window station (no visual styles) or when the Aqua Light Slate style
    ///   file is not installed.
    /// </summary>
    [Test] procedure SpecialLineColors_SeededFromStyleWhenStyled;
    /// <summary>
    ///   Proves fe0545e: DigitCount accepts 16 and 24 (a 64-bit hexadecimal
    ///   offset needs 16), clamps 25 to the new ceiling 24, and still clamps
    ///   below the floor of 2.  Before the fix 16 and 24 both read back as 12.
    /// </summary>
    [Test] procedure GutterDigitCount_AcceptsUpTo24;
  end;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  System.UITypes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Themes,
  GllDUnitX.Station,
  SynEdit;

type
  /// <summary>One OnSpecialLineColors call as the handler saw it on entry.</summary>
  TColourCall = record
    /// <summary>The line the event was raised for.</summary>
    Line: NativeInt;
    /// <summary>FG on entry, before the handler touched it.</summary>
    FG: TColor;
    /// <summary>BG on entry, before the handler touched it.</summary>
    BG: TColor;
  end;

  /// <summary>Records what OnSpecialLineColors receives, and changes only ONE colour per line.</summary>
  TColourRecorder = class
  strict private
    FCalls: TList<TColourCall>;
  public
    /// <summary>Creates the empty call list.</summary>
    constructor Create;
    /// <summary>Frees the call list.</summary>
    destructor Destroy; override;
    /// <summary>
    ///   The event handler: records FG and BG as received, then on line 1 sets
    ///   only FG and on line 2 only BG, leaving the other one as it came in.
    /// </summary>
    /// <param name="Sender">The editor.</param>
    /// <param name="Line">The line being painted.</param>
    /// <param name="Special">Set True on lines 1 and 2.</param>
    /// <param name="FG">The foreground colour; changed only on line 1.</param>
    /// <param name="BG">The background colour; changed only on line 2.</param>
    procedure SpecialLineColors(Sender: TObject; Line: NativeInt; var Special: Boolean; var FG, BG: TColor);
    /// <summary>Every call recorded, in paint order.</summary>
    property Calls: TList<TColourCall> read FCalls;
  end;

const
  CFontColour = TColor($00336699);
  CBackColour = TColor($00CCEEFF);
  CStyleName = 'Aqua Light Slate';

constructor TColourRecorder.Create;
begin
  inherited Create;
  FCalls := TList<TColourCall>.Create;
end;

destructor TColourRecorder.Destroy;
begin
  FCalls.Free;
  inherited;
end;

procedure TColourRecorder.SpecialLineColors(Sender: TObject; Line: NativeInt; var Special: Boolean; var FG,
  BG: TColor);
var
  Call: TColourCall;
begin
  Call.Line := Line;
  Call.FG := FG;
  Call.BG := BG;
  FCalls.Add(Call);
  case Line of
    1:
      begin
        Special := True;
        FG := clRed;
      end;
    2:
      begin
        Special := True;
        BG := clBlue;
      end;
  end;
end;

// Paints a three-line editor into a bitmap and returns what the handler saw.
// The form is created, never shown: PaintTo needs a window handle, not a
// visible window.
procedure PaintAndRecord(ARecorder: TColourRecorder);
var
  Form: TForm;
  Ed: TSynEdit;
  Bmp: Vcl.Graphics.TBitmap;
begin
  Form := TForm.CreateNew(nil);
  try
    Ed := TSynEdit.Create(Form);
    Ed.Parent := Form;
    Ed.SetBounds(0, 0, 400, 200);
    Ed.Font.Color := CFontColour;
    Ed.Color := CBackColour;
    Ed.Lines.Text := 'one'#13#10'two'#13#10'three';
    Ed.OnSpecialLineColors := ARecorder.SpecialLineColors;
    Ed.HandleNeeded;
    Bmp := Vcl.Graphics.TBitmap.Create(400, 200);
    try
      Ed.PaintTo(Bmp.Canvas, 0, 0);
    finally
      Bmp.Free;
    end;
  finally
    Form.Free;
  end;
end;

{ TEditorColourTests }

procedure TEditorColourTests.SpecialLineColors_SeededFromFontAndColor;
var
  Recorder: TColourRecorder;
begin
  Recorder := TColourRecorder.Create;
  try
    PaintAndRecord(Recorder);
    Assert.IsTrue(Recorder.Calls.Count >= 3, Format('the paint must reach all three lines, got %d calls',
      [Recorder.Calls.Count]));
    for var Call in Recorder.Calls do
    begin
      Assert.AreEqual(Integer(CFontColour), Integer(Call.FG), Format('FG on entry, line %d', [Call.Line]));
      Assert.AreEqual(Integer(CBackColour), Integer(Call.BG), Format('BG on entry, line %d', [Call.Line]));
    end;
  finally
    Recorder.Free;
  end;
end;

procedure TEditorColourTests.SpecialLineColors_SeededFromStyleWhenStyled;
var
  Recorder: TColourRecorder;
  StyleFile: string;
  ExpectedFG, ExpectedBG: TColor;
begin
  // A non-interactive window station (GITLAKMCP's service) has no visual
  // styles, so no VCL style can be loaded there.
  RequireInteractiveStation('a VCL style, which needs visual styles');
  StyleFile := 'C:\Users\Public\Documents\Embarcadero\Studio\37.0\Styles\AquaLightSlate.vsf';
  if not TFile.Exists(StyleFile) then
    Assert.Ignore('style file not installed: ' + StyleFile);
  if TStyleManager.Style[CStyleName] = nil then
    TStyleManager.LoadFromFile(StyleFile);
  TStyleManager.SetStyle(CStyleName);
  try
    ExpectedFG := StyleServices.GetSystemColor(clWindowText);
    ExpectedBG := StyleServices.GetStyleColor(scEdit);
    Assert.AreNotEqual(Integer(CFontColour), Integer(ExpectedFG), 'the style must not paint with Font.Color');
    Assert.AreNotEqual(Integer(CBackColour), Integer(ExpectedBG), 'the style must not paint with Color');
    Recorder := TColourRecorder.Create;
    try
      PaintAndRecord(Recorder);
      Assert.IsTrue(Recorder.Calls.Count >= 3, Format('the paint must reach all three lines, got %d calls',
        [Recorder.Calls.Count]));
      for var Call in Recorder.Calls do
      begin
        Assert.AreEqual(Integer(ExpectedFG), Integer(Call.FG), Format('styled FG on entry, line %d', [Call.Line]));
        Assert.AreEqual(Integer(ExpectedBG), Integer(Call.BG), Format('styled BG on entry, line %d', [Call.Line]));
      end;
    finally
      Recorder.Free;
    end;
  finally
    TStyleManager.SetStyle(TStyleManager.SystemStyleName);
  end;
end;

procedure TEditorColourTests.GutterDigitCount_AcceptsUpTo24;
var
  Ed: TSynEdit;
begin
  Ed := TSynEdit.Create(nil);
  try
    Ed.Gutter.DigitCount := 16;
    Assert.AreEqual(NativeInt(16), NativeInt(Ed.Gutter.DigitCount), '16 digits: a 64-bit hexadecimal offset');
    Ed.Gutter.DigitCount := 24;
    Assert.AreEqual(NativeInt(24), NativeInt(Ed.Gutter.DigitCount), '24 is the new ceiling');
    Ed.Gutter.DigitCount := 25;
    Assert.AreEqual(NativeInt(24), NativeInt(Ed.Gutter.DigitCount), '25 clamps to 24');
    Ed.Gutter.DigitCount := 1;
    Assert.AreEqual(NativeInt(2), NativeInt(Ed.Gutter.DigitCount), 'the floor of 2 is unchanged');
  finally
    Ed.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEditorColourTests);

end.
