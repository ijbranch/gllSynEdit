{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynURIOpener.pas, released 2003-09-25.
The Initial Author of this file is Maël Hörz.
Unicode translation by Maël Hörz.
All Rights Reserved.

Contributors to the SynEdit project are listed in the Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

You may retrieve the latest version of SynEdit from the SynEdit home page,
located at http://SynEdit.SourceForge.net

-------------------------------------------------------------------------------}
{
@abstract(Plugin for SynEdit to make links (URIs) clickable)
@author(Maël Hörz)
@created(2003)
@lastmod(2004-03-19)
The SynURIOpener unit extends SynEdit to make links highlighted by SynURISyn
clickable.

http://www.mh-net.de.vu
}

unit SynURIOpener;

{$I SynEdit.inc}
              
interface

uses
  Windows,
  Controls,
  SynEditTypes,
  SynEdit,
  SynFunc,
  SynHighlighterURI,
  SynUnicode,
  Classes;

type
  /// <summary>Reports a link that could not be launched.</summary>
  /// <param name="Sender">The TSynURIOpener that attempted the launch.</param>
  /// <param name="URI">The URI as handed to ShellExecute, including any
  /// scheme prefix the opener added.</param>
  /// <param name="ErrorCode">The ShellExecute failure code (&lt;= 32), for
  /// example ERROR_FILE_NOT_FOUND or SE_ERR_NOASSOC.</param>
  TSynURIOpenErrorEvent = procedure(Sender: TObject; const URI: string;
    ErrorCode: Integer) of object;

  TSynURIOpener = class(TComponent)
  private
    FControlDown: Boolean;
    FCtrlActivatesLinks: Boolean;
    FEditor: TCustomSynEdit;
    FMouseDownX: TSynNativeInt;
    FMouseDownY: TSynNativeInt;
    FOnOpenError: TSynURIOpenErrorEvent;

    FURIHighlighter: TSynURISyn;
    FVisitedURIs: TStringList;
    /// <summary>Records the URI as visited and launches it with ShellExecute.
    /// On failure the visited entry is rolled back and OnOpenError is
    /// fired.</summary>
    /// <param name="URI">The link text as found by the highlighter, without
    /// any scheme prefix this method may add.</param>
    /// <param name="LinkType">The highlighter token kind, cast to
    /// TtkTokenKind, that decides the scheme prefix.</param>
    procedure OpenLink(URI: string; LinkType: TSynNativeInt);
    function MouseInSynEdit: Boolean;
  protected
    procedure NewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure NewKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure NewMouseCursor(Sender: TObject; const aLineCharPos: TBufferCoord;
      var aCursor: TCursor);
    procedure NewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure NewMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    procedure SetEditor(const Value: TCustomSynEdit);
    procedure SetURIHighlighter(const Value: TSynURISyn);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VisitedURI(URI: string): Boolean;
  published
    property CtrlActivatesLinks: Boolean read FCtrlActivatesLinks
      write FCtrlActivatesLinks default True;
    property Editor: TCustomSynEdit read FEditor write SetEditor;
    property URIHighlighter: TSynURISyn read FURIHighlighter 
      write SetURIHighlighter;
    /// <summary>Fired when ShellExecute fails to launch a clicked link. The
    /// URI is also removed again from the visited list, so a failed link is
    /// not rendered as visited.</summary>
    property OnOpenError: TSynURIOpenErrorEvent read FOnOpenError
      write FOnOpenError;
  end;


implementation

uses
  ShellAPI,
  Forms,
  SynEditHighlighter,
  SynEditKeyConst,
  SysUtils;

type
  TAccessCustomSynEdit = class(TCustomSynEdit);
  TAccessSynURISyn = class(TSynURISyn);

{ TSynURIOpener }

constructor TSynURIOpener.Create(AOwner: TComponent);
begin
  inherited;
  FCtrlActivatesLinks := True;
  FVisitedURIs := TStringList.Create;
  FVisitedURIs.Sorted := True;
end;

destructor TSynURIOpener.Destroy;
begin
  FVisitedURIs.Free;
  inherited;
end;

function TSynURIOpener.MouseInSynEdit: Boolean;
var
  pt: TPoint;
begin
  pt := Mouse.CursorPos;
  Result := PtInRect(FEditor.ClientRect, FEditor.ScreenToClient(pt))
end;

procedure TSynURIOpener.NewKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = SYNEDIT_CONTROL) and not FControlDown and MouseInSynEdit then
  begin
    FControlDown := True;
    TAccessCustomSynEdit(FEditor).UpdateMouseCursor;
  end;
end;

procedure TSynURIOpener.NewKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = SYNEDIT_CONTROL) and FControlDown then
  begin
    FControlDown := False;
    TAccessCustomSynEdit(FEditor).UpdateMouseCursor;
  end;
end;

function IsControlPressed: Boolean;
begin
  // GetKeyState, not GetAsyncKeyState: the latter's bit 0 means "pressed since
  // the last call for this key", so a Ctrl shortcut used elsewhere would make
  // the next mouse move believe Ctrl is still held
  Result := GetKeyState(VK_CONTROL) < 0;
end;

procedure TSynURIOpener.NewMouseCursor(Sender: TObject;
  const aLineCharPos: TBufferCoord; var aCursor: TCursor);
var
  TokenType, Start: TSynNativeInt;
  Token: string;
  Attri: TSynHighlighterAttributes;
begin
  FControlDown := IsControlPressed;
  if not(FCtrlActivatesLinks and not FControlDown or
    (csDesigning in FEditor.ComponentState)) and FEditor.Focused
  then
    with FEditor do
    begin
      GetHighlighterAttriAtRowColEx(aLineCharPos, Token, TokenType, Start, Attri);
      if Assigned(URIHighlighter) and ((Attri = URIHighlighter.URIAttri) or
        (Attri = URIHighlighter.VisitedURIAttri)) and
        not((eoDragDropEditing in Options) and IsPointInSelection(aLineCharPos))
      then
        aCursor := crHandPoint
    end
end;

procedure TSynURIOpener.NewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and not(FCtrlActivatesLinks) or FControlDown then
  begin
    FMouseDownX := X;
    FMouseDownY := Y;
  end
end;

procedure TSynURIOpener.NewMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ptLineCol: TBufferCoord;
  TokenType, Start: TSynNativeInt;
  Token: string;
  Attri: TSynHighlighterAttributes;
begin
  if (Button <> mbLeft) or (FCtrlActivatesLinks and not FControlDown) or
    (Abs(FMouseDownX - X) > 4) or (Abs(FMouseDownY - Y) > 4) then Exit;

  with TAccessCustomSynEdit(FEditor) do
  begin
    if (eoDragDropEditing in Options) and IsPointInSelection(ptLineCol) then
      Exit;

    if X >= fGutterWidth then
    begin
      ptLineCol := DisplayToBufferPos(PixelsToRowColumn(X,Y));

      GetHighlighterAttriAtRowColEx(ptLineCol, Token, TokenType, Start, Attri);
      if Assigned(URIHighlighter) and ((Attri = URIHighlighter.URIAttri) or
        (Attri = URIHighlighter.VisitedURIAttri)) and
        not((eoDragDropEditing in Options) and IsPointInSelection(ptLineCol)) then
      begin
        OpenLink(Token, TokenType);
        InvalidateLine(ptLineCol.Line);
      end;
    end
  end;
end;

procedure TSynURIOpener.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and Assigned(Editor) and (AComponent = Editor) then
    Editor := nil;
  if (Operation = opRemove) and Assigned(URIHighlighter) and
    (AComponent = URIHighlighter)
  then
    URIHighlighter := nil;
end;

procedure TSynURIOpener.OpenLink(URI: string; LinkType: TSynNativeInt);
var
  Original: string;
  VisitedIndex: Integer;   // TStringList.Find takes a var Integer
  WasVisited: Boolean;
  ShellResult: HINST;
begin
  Original := URI;
  // The list is sorted, so Add of an entry that is already there is a no-op -
  // remember that, or a failed launch would drop a genuinely visited URI
  WasVisited := FVisitedURIs.Find(Original, VisitedIndex);
  if not WasVisited then
    FVisitedURIs.Add(Original);

  case TtkTokenKind(LinkType) of
    tkMailtoLink:
      if (Pos('mailto:', URI) <> 1) then URI := 'mailto:' + URI;
    tkWebLink:
       URI := 'http://' + URI;
  end;

  ShellResult := ShellExecute(0, nil, PChar(URI), nil, nil, SW_SHOWNORMAL);
  if ShellResult <= 32 then
  begin
    // The link never opened, so it must not stay marked as visited
    if not WasVisited and FVisitedURIs.Find(Original, VisitedIndex) then
      FVisitedURIs.Delete(VisitedIndex);
    if Assigned(FOnOpenError) then
      FOnOpenError(Self, URI, Integer(ShellResult));
  end;
end;

procedure TSynURIOpener.SetEditor(const Value: TCustomSynEdit);
begin
  if Editor <> Value then
  begin
    if (csDesigning not in ComponentState) and Assigned(FEditor) then
    begin
      with FEditor do
      begin
        RemoveKeyDownHandler(NewKeyDown);
        RemoveKeyUpHandler(NewKeyUp);
        RemoveMouseCursorHandler(NewMouseCursor);
        RemoveMouseDownHandler(NewMouseDown);
        RemoveMouseUpHandler(NewMouseUp);
      end;
    end;

    FEditor := Value;

    if (csDesigning not in ComponentState) and Assigned(FEditor) then
    begin
      with FEditor do
      begin
        AddKeyDownHandler(NewKeyDown);
        AddKeyUpHandler(NewKeyUp);
        AddMouseCursorHandler(NewMouseCursor);
        AddMouseDownHandler(NewMouseDown);
        AddMouseUpHandler(NewMouseUp);
      end;
    end;
  end;
end;

procedure TSynURIOpener.SetURIHighlighter(const Value: TSynURISyn);
begin
  if (csDesigning not in ComponentState) and Assigned(URIHighlighter) then
    TAccessSynURISyn(FURIHighlighter).SetAlreadyVisitedURIFunc(nil);

  FURIHighlighter := Value;

  if (csDesigning not in ComponentState) and  Assigned(URIHighlighter) then
    TAccessSynURISyn(FURIHighlighter).SetAlreadyVisitedURIFunc(VisitedURI);
end;

function TSynURIOpener.VisitedURI(URI: string): Boolean;
var
  Dummy: Integer;
begin
  Result := FVisitedURIs.Find(URI, Dummy);
end;

const
  IDC_LINK = MakeIntResource(32649);

var
  CursorHandle: THandle;

initialization
  // Hand TScreen a private copy: TScreen.DeleteCursor calls DestroyCursor on
  // the outgoing entry, which must never be done to a shared system cursor.
  // CopyIcon is what the Win32 CopyCursor macro resolves to; the RTL declares
  // no CopyCursor of its own
  CursorHandle := CopyIcon(LoadCursor(0, IDC_LINK));
  if CursorHandle <> 0 then
    Screen.Cursors[crHandPoint] := CursorHandle;

end.
