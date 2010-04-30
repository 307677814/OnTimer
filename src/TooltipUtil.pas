{
    �޸��ߣ�ghs
    ���ڣ�20071218
    ���ܣ���ԭ�汾�Ļ��������ӡ�
          RegisterControl��ע����Ҫ��ʾ�Ŀؼ���
          BeginHelp�����ù��״̬Ϊ����crHelp��
          ��굯�����ʾע�����ʾ��Ϣ��ͬʱ�����л�ԭ��

   ԭ�汾
   ���ߣ�thaoqi
   ������http://www.2ccc.com/article.asp?articleid=4389
   ���ܣ�����ллxsherry��������Ӻܳ�һ��ʱ���ˣ������¶�����û��Ϊ������ʲô���ס�
        ǰ��ʱ��xsherry�����ש��������£����������ܴ����һ����Ŀ���Ҫ����
        ��������������кã���������MessageBox�����������Ļ����ϣ�����ͼģ��XP
        ��¼ʱ����Ǹ�ToolTip��ʾ���ܣ���API������һ������Ҫ���ToolTip��ʾ���
        ��������Ұ�ʵ�ֵĺ�����װ����һ��VCL�Ŀؼ���ϣ������ܶ��������
}
unit TooltipUtil;

interface

uses Messages, Windows, SysUtils, Classes, Contnrs, Controls, CommCtrl,
  StdCtrls, ExtCtrls, Consts, Forms, Dialogs, AppEvnts;

type
  TTipTool_ICON = (ttNoneIcon, ttInformationIcon, ttWarningIcon, ttStopIcon);
  TTipAlignment = (taLeft, taCenter, taRight);

  PTipInfo = ^TTipInfo;

  TTipInfo = packed record
    WinControl: TWinControl;
    Handle: THandle;
    Caption: string;
    Msg: string;
    TipICON: TTipTool_ICON;
    TipAlg: TTipAlignment;
    Cursor: TCursor;
  end;

  TToolTip = class(TComponent)
  private
    FTitle: string;
    FText: string;
    FEnabled: Boolean;
    FWindowHandle: HWND;
    FTipHandle: HWND;
    FInterval: Cardinal;
    FToolInfo: TToolInfo;
    FAlignment: TTipAlignment;
    FTipIcon: TTipTool_ICON;
    FControl: TWinControl;
    //
    Flist: TList;
    ApplicationEvents: TApplicationEvents;
    FLastHandle: THandle;

    procedure SetText(AText: string);   //����������ʾ��Ϣ
    procedure SetTitle(ATitle: string); //����������ʾ�ı���

    procedure UpdateTime;               //���¼�ʱ��״̬
    procedure WndProc(var Msg: TMessage); //����windows��Ϣ
  protected
    //������Ϣ=�����������
    procedure ApplicationEvents1Message(var Msg: tagMSG;
      var Handled: Boolean);
    //��������=���ù��Ϊ�ؼ�����״̬
    procedure EndHelp;
  public
    constructor Create(AOwner: TComponent); override; //���캯��������ʵ��
    destructor Destroy; override;       //��������������ʵ��
    //ע��ؼ���Ϣ
    procedure RegisterControl(WinControl: TWinControl; aCaption, aMsg: string;
      TipICON: TTipTool_ICON = ttInformationIcon; TipAlignment: TTipAlignment = taLeft);
    //��ʼ����=���ù��״̬
    procedure BeginHelp;
    procedure Popup(Handle: HWND); overload; //��ָ���ľ���е������ݣ����أ�
    procedure Popup(Handle: HWND; IconType: TTipTool_ICON; Title,
      Text: string); overload;          //��ָ���ľ���е������ݣ����أ�
    procedure EndPopup;
  published
    //���ݴ���Ĵ�����
    property Handle: HWND read fTipHandle;
    //���ݴ������ʾ��Ϣ
    property Text: string read fText write SetText;
    //���ݴ���ı�����Ϣ
    property Title: string read fTitle write SetTitle;
    //���ݴ������Ϣͼ��
    property ICON: TTipTool_ICON read fTipIcon write fTipIcon;
    //���ݴ��嵯��ʱ����λ��
    property Alignment: TTipAlignment read fAlignment write fAlignment default taLeft;
    //���ݴ������ʾʱ��
    property Interval: Cardinal read fInterval write fInterval default 1000;
  end;

procedure Register;

implementation

const
  TTS_BALLOON       = $0040;            //ToolTip��ʾ���ڵ����Σ�ָ��Ϊ������
  TTS_CLOSE         = $0080;            //�رհ�ť
  TTF_PARSELINKS    = $1000;            //��ʹ�ó�����
  TTM_SETTITLE      = WM_USER + 32;     //������ʾ������Ϣ����Ϣ

var
  DefTipProc        : Pointer;

function TipWndProc(WinHanlde, MessageID, WParam, LParam: LongWord): Longint; stdcall;
begin
  result := CallWindowProc(DefTipProc, WinHanlde, messageid, wparam, lparam);
  case messageid of
    WM_LBUTTONDOWN, WM_RBUTTONDOWN,
      WM_NCLBUTTONDOWN, WM_NCRBUTTONDOWN:
      SendMessage(WinHanlde, TTM_TRACKACTIVATE, Integer(false), 0);
  end;
end;

constructor TToolTip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  if not (AOwner is TWinControl) then
  begin
    raise exception.Create('TToolTip''s owner must be a ''TWinControl'' type.');
    Destroy;
  end;

  fWindowHandle := Classes.AllocateHWnd(WndProc);

  fEnabled := False;
  fInterval := 1000;

  //����������ʾ����
  fTipHandle := CreateWindow(TOOLTIPS_CLASS, nil,
    WS_POPUP or TTS_NOPREFIX or
    TTS_BALLOON or TTS_ALWAYSTIP,       // or TTS_CLOSE,
    0, 0, 0, 0, fWindowHandle,
    0, HInstance, nil);

  defTipProc := pointer(GetWindowLong(FTipHandle, GWL_WndProc));
  SetWindowLong(FTipHandle, GWL_WNDPROC, longint(@TipwndProc));
  if fTipHandle <> 0 then
  begin
    //����ToolInfo�Ĵ�С
    fToolInfo.cbSize := SizeOf(fToolInfo);
    //���û������
    fToolInfo.uFlags := TTF_PARSELINKS or TTF_IDISHWND or TTF_TRACK;
    //���������ߵľ��
    fToolInfo.uId := fWindowHandle;
  end;
  Flist := TList.Create;
  ApplicationEvents := TApplicationEvents.Create(nil);
  ApplicationEvents.OnMessage := ApplicationEvents1Message;
end;

destructor TToolTip.Destroy;
var
  I                 : Integer;
  tmpTipInfo        : PTipInfo;
begin
  if fTipHandle <> 0 then
    CloseWindow(fTipHandle);
  for I := Flist.Count - 1 downto 0 do  // Iterate
  begin
    tmpTipInfo := PTipInfo(FList.Items[i]);
    Dispose(tmpTipInfo);
  end;                                  // for
  Flist.Free;
  ApplicationEvents.Free;
  DeallocateHWnd(fWindowHandle);
  inherited Destroy;
end;

procedure TToolTip.SetText(AText: string);
begin
  fText := AText;

  if fTipHandle <> 0 then
  begin
    //���ñ�����Ϣ
    fToolInfo.lpszText := PAnsiChar(fText);
    //�����ݴ��巢����Ϣ����ToolInfo����Ϣ���õ����ݴ�����
    SendMessage(fTipHandle, TTM_ADDTOOL, 0, Integer(@fToolInfo));
    SendMessage(fTipHandle, TTM_SETTOOLINFO, 0, Integer(@fToolInfo));
  end;
end;

procedure TToolTip.SetTitle(ATitle: string);
begin
  fTitle := ATitle;

  if fTipHandle <> 0 then
    //�������ݴ������ʾͼ��ͱ�����Ϣ
    SendMessage(fTipHandle, TTM_SETTITLE, Integer(fTipIcon), Integer(fTitle));
end;

procedure TToolTip.Popup(Handle: HWND);
var
  tmpRect           : TRect;
  x, y              : word;
begin
  x := 0;

  fControl := FindControl(Handle);
  if fControl.Hint <> '' then
    fControl.ShowHint := False;

  //�õ���Ҫ��ʾ�������ڵ���Ļ����
  GetWindowRect(Handle, tmpRect);

  //������ʾ����λ�õ�����
  with tmpRect do
  begin
    y := (Bottom - Top) div 2 + Top;

    case fAlignment of
      taLeft: x := Left;
      taCenter: x := (Right - Left) div 2 + Left;
      taRight: x := Right;
    end;
  end;

  //�������ݴ��嵯��������
  SendMessage(fTipHandle, TTM_TRACKPOSITION, 0, MAKELONG(x, y));
  //�������ݴ��壬����ʾ����
  SendMessage(fTipHandle, TTM_TRACKACTIVATE, Integer(True), Integer(@fToolInfo));

  fEnabled := True;
  //���¼�ʱ��״̬
  UpdateTime;
end;

procedure TToolTip.WndProc(var Msg: TMessage);
begin
  fEnabled := False;
  with Msg do
  begin
    case Msg of
      WM_TIMER:
        try
          SendMessage(fTipHandle, TTM_TRACKACTIVATE,
            Integer(False), Integer(@fToolInfo));
          if fControl.Hint <> '' then
            fControl.ShowHint := True;
        except
          Application.HandleException(Self);
        end;
    else
      Result := DefWindowProc(fWindowHandle, Msg, wParam, lParam);
    end;
  end;
  //���¼�ʱ��״̬
  UpdateTime;
end;

procedure TToolTip.Popup(Handle: HWND; IconType: TTipTool_ICON;
  Title: string; Text: string);
begin
  fTipIcon := IconType;

  SetTitle(Title);
  SetText(Text);

  Popup(Handle);
end;

procedure TToolTip.UpdateTime;
begin
  KillTimer(fWindowHandle, 1);
  if (FInterval <> 0) and FEnabled then
    if SetTimer(fWindowHandle, 1, FInterval, nil) = 0 then
      raise EOutOfResources.Create(SNoTimers);
end;

procedure Register;
begin
  RegisterComponents('ToolTip', [TToolTip]);
end;

procedure TToolTip.RegisterControl(WinControl: TWinControl; aCaption, aMsg: string;
  TipICON: TTipTool_ICON = ttInformationIcon; TipAlignment: TTipAlignment = taLeft);
var
  TipInfo           : PTipInfo;
begin
  New(TipInfo);
  TipInfo.WinControl := WinControl;
  TipInfo.Handle := WinControl.Handle;
  TipInfo.Caption := aCaption;
  Tipinfo.Msg := aMsg;
  TipInfo.TipICON := TipICON;
  TIpInfo.TipAlg := TipAlignment;
  TipInfo.Cursor := WinControl.Cursor;

  Flist.Add(TipInfo);
end;

procedure TToolTip.ApplicationEvents1Message(var Msg: tagMSG;
  var Handled: Boolean);
var
  I                 : Integer;
  tmpTipInfo        : PTipInfo;
  tmpPoint          : TPoint;
  tmpHandle         : THandle;
begin
  if Msg.message = WM_LBUTTONUP then
  begin
    GetCurSorPos(tmpPoint);
    tmpHandle := WindowFromPoint(tmpPoint);
    if FLastHandle <> tmpHandle then    //��ֹ��ͣ����
    begin
      FLastHandle := tmpHandle;
      for I := 0 to FList.Count - 1 do  // Iterate
      begin
        tmpTipInfo := PTipInfo(FList.Items[i]);
        //ֻ�е�����BeginHelp���Żᵯ����ʾ����
        if (tmpTipInfo.Handle = tmpHandle) and (tmpTipInfo.WinControl.Cursor = crHelp) then
        begin
          Popup(tmpHandle, tmpTipInfo.TipICON, tmpTipInfo.Caption, tmpTipInfo.Msg);
          break;
        end;
      end;                              // for
      EndHelp;
      DefWindowProc(Msg.hwnd, Msg.message, Msg.wParam, Msg.lParam);
    end;
  end;

end;

procedure TToolTip.BeginHelp;
var
  i                 : Integer;
  tmpTipInfo        : PTipInfo;
begin
  for I := 0 to FList.Count - 1 do      // Iterate
  begin
    tmpTipInfo := PTipInfo(FList.Items[i]);
    tmpTipInfo.WinControl.Cursor := crHelp;
  end;                                  // for
end;

procedure TToolTip.EndHelp;
var
  i                 : Integer;
  tmpTipInfo        : PTipInfo;
begin
  for I := 0 to FList.Count - 1 do      // Iterate
  begin
    tmpTipInfo := PTipInfo(FList.Items[i]);
    tmpTipInfo.WinControl.Cursor := tmpTipInfo.Cursor;
  end;                                  // for
end;

procedure TToolTip.EndPopup;
begin
  SendMessage(fTipHandle, TTM_TRACKACTIVATE, Integer(false), 0);
end;

end.

