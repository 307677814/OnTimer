unit frmAddTask_u;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Graphics,
  ComCtrls, StdCtrls, Spin, TaskMgr_u, TooltipUtil;

type
  TfrmAddTask = class(TForm)
    grpTask: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    cbbType: TComboBox;
    seExecNum: TSpinEdit;
    btnOk: TButton;
    btnCancel: TButton;
    edtTime: TEdit;
    chkEveryDay: TCheckBox;
    chkLoop: TCheckBox;
    InfoLabel1: TLabel;
    lbl1: TLabel;
    lblParam: TLabel;
    edtParam: TEdit;
    chkWeek: TCheckBox;
    chkMon: TCheckBox;
    chkTue: TCheckBox;
    chkWed: TCheckBox;
    chkThu: TCheckBox;
    chkFri: TCheckBox;
    chkSat: TCheckBox;
    chkSun: TCheckBox;
    chkTmpExecNum: TCheckBox;
    chkMonthly: TCheckBox;
    lbl2: TLabel;
    cbbClass: TComboBox;
    mmoContent: TMemo;
    chkActive: TCheckBox;
    procedure btnOkClick(Sender: TObject);
    procedure chkEveryDayClick(Sender: TObject);
    procedure cbbTypeChange(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
    procedure chkWeekClick(Sender: TObject);
    procedure mmoContentEnter(Sender: TObject);
    procedure edtParamEnter(Sender: TObject);
    procedure mmoContentExit(Sender: TObject);
  private
    FTask: TTask;
    FToolTip: TToolTip;
    FContentTip: string;
    FParamTip: string;
  public
    constructor Create(Task: TTask);
  end;

var
  frmAddTask        : TfrmAddTask;

implementation
uses
  Proc_u;
{$R *.dfm}

constructor TfrmAddTask.Create(Task: TTask);
var
  i                 : Integer;
  weekSet           : TWeekSet;

  SelItem           : TListItem;
  SelNode           : TTreeNode;
begin
  inherited Create(Application);
  FTask := Task;

  FToolTip := TToolTip.Create(Self);
  FToolTip.Interval := 5000;

  SelItem := g_TaskMgr.Lv.Selected;
  SelNode := g_TaskMgr.Classes.Tv.Selected;

  //����
  cbbType.Clear;
  for i := 0 to Integer(High(TTaskType)) do
    cbbType.Items.Add(TASK_TYPE_STR[TTaskType(i)]);
  cbbType.ItemIndex := 0;

  //����
  cbbClass.Clear;
  cbbClass.AddItem('δ����', TObject(0));
  with g_TaskMgr.Classes.ClassNode[tcByClass] do
    for i := 0 to Count - 1 do
      cbbClass.AddItem(Item[i].Text, Item[i].Data);
  cbbClass.ItemIndex := 0;

  { �������� }
  if Assigned(Task) then                //Edit
  begin
    chkActive.Checked := Task.Active;
    cbbType.ItemIndex := Integer(Task.TaskType);
    cbbClass.ItemIndex := cbbClass.Items.IndexOfObject(TObject(Task.CId));
    seExecNum.Value := Task.ExecNum;
    chkTmpExecNum.Checked := Task.TmpExecNum;

    case Task.TimeType of
      tmLoop, tmTime:
        begin
          if Task.TimeType = tmLoop then
          begin
            chkLoop.Checked := True;
            edtTime.Text := IntToStr(Task.TimeRec.TimeOrLoop);
          end
          else
          begin
            chkEveryDay.Checked := True;
            edtTime.Text := FormatDateTime(DATETIME_FORMAT_SETTINGS.LongTimeFormat,
              TimeStampToDateTime(PTimeStamp(@Task.TimeRec)^));
          end;
          { ��������Ҫ��ʱ���������ã��� }
          if Task.IsWeek then
          begin
            chkWeek.Checked := True;
            weekSet := PWeekSet(@Task.TimeRec.DateOrWeek)^;
            chkMon.Checked := wdMon in weekSet;
            chkTue.Checked := wdTue in weekSet;
            chkWed.Checked := wdWed in weekSet;
            chkThu.Checked := wdThu in weekSet;
            chkFri.Checked := wdFri in weekSet;
            chkSat.Checked := wdSat in weekSet;
            chkSun.Checked := wdSun in weekSet;
          end;
        end;

      tmDateTime:
        begin
          edtTime.Text := FormatDateTime(DATETIME_FORMAT_SETTINGS.LongDateFormat,
            TimeStampToDateTime(PTimeStamp(@Task.TimeRec)^));
        end;

      tmMonthly:
        begin
          chkMonthly.Checked := True;
          edtTime.Text := IntToStr(Task.TimeRec.DateOrWeek) + ' '
            + FormatDateTime(DATETIME_FORMAT_SETTINGS.LongTimeFormat,
            TimeStampToDateTime(PTimeStamp(@Task.TimeRec)^));
        end;
    end;

    edtParam.Text := Task.Param;
    mmoContent.Text := Task.Content;
  end
  else                                  //Add
  begin
    edtTime.Text := FormatDateTime(DATETIME_FORMAT_SETTINGS.LongDateFormat, now);

    //Default
    if SelItem <> nil then
    begin
      cbbType.ItemIndex := Integer(TTask(SelItem.Data).TaskType);
      cbbClass.ItemIndex := cbbClass.Items.IndexOfObject(TObject(TTask(SelItem.Data).CId));
    end;

    if (SelNode <> nil) then
      if (SelNode.Parent = g_TaskMgr.Classes.ClassNode[tcByType]) then //������
        cbbType.ItemIndex := Integer(SelNode.Data)
      else if (SelNode.Parent = g_TaskMgr.Classes.ClassNode[tcByClass]) then //������
        cbbClass.ItemIndex := cbbClass.Items.IndexOfObject(SelNode.Data);
  end;

  cbbTypeChange(cbbType);
end;

procedure TfrmAddTask.btnOkClick(Sender: TObject);
var
  S                 : string;
  n                 : Integer;
  bErr, isAdd       : Boolean;
  timeType          : TTimeType;
  dateTime          : TDateTime;
  timeRec           : TTimeRec;
  weekSet           : TWeekSet;

  Item              : TListItem;
begin
  bErr := False;

  timeType := tmDateTime;
  if chkLoop.Checked then
  begin                                 { ����ʱ }
    if not TryStrToInt(edtTime.Text, Integer(timeRec.TimeOrLoop)) then
      bErr := true;
    //    if loopTime > MAX_LOOP_VALUE then begin
    //      FToolTip.Popup(edtTime.Handle, ttWarningIcon,
    //        '��ʾ', '��ʱ���ܴ���' + IntToStr(MAX_LOOP_VALUE) + '��!');
    //      Exit;
    //    end;
    timeType := tmLoop;
  end
  else if TryStrToDateTime(edtTime.Text, dateTime, DATETIME_FORMAT_SETTINGS) then
  begin                                 { ʱ�䡢���� }
    if chkEveryDay.Checked then
    begin
      timeType := tmTime;
      timeRec.TimeOrLoop := DateTimeToTimeStamp(dateTime).Time;
    end
    else
    begin
      timeType := tmDateTime;
      PTimeStamp(@timeRec)^ := DateTimeToTimeStamp(dateTime);
    end;
  end
  else if chkMonthly.Checked then
  begin                                 { ÿ�� 24 22:29:00}
    S := edtTime.Text;
    bErr := not (
      (S[1] in ['0'..'3']) and (S[2] in ['0'..'9']) and (S[3] = ' ')
      and not TryStrToInt(S, n) and (n > 0) and (n <= 31)
      and TryStrToDateTime(Copy(S, 4, 8), dateTime, DATETIME_FORMAT_SETTINGS)
      );

    if not bErr then
    begin
      timeType := tmMonthly;
      timeRec.DateOrWeek := n;
      timeRec.TimeOrLoop := DateTimeToTimeStamp(dateTime).Time;
    end;
  end
  else
    bErr := True;

  if not (timeType in [tmDateTime, tmMonthly]) then
  begin
    weekSet := [wdNone];
    if chkWeek.Checked then
    begin
      if chkMon.Checked then
        weekSet := weekSet + [wdMon];
      if chkTue.Checked then
        weekSet := weekSet + [wdTue];
      if chkWed.Checked then
        weekSet := weekSet + [wdWed];
      if chkThu.Checked then
        weekSet := weekSet + [wdThu];
      if chkFri.Checked then
        weekSet := weekSet + [wdFri];
      if chkSat.Checked then
        weekSet := weekSet + [wdSat];
      if chkSun.Checked then
        weekSet := weekSet + [wdSun];
    end;
    timeRec.DateOrWeek := 0;            //���
    PWeekSet(@timeRec.DateOrWeek)^ := weekSet;
  end;

  if bErr then
  begin
    FToolTip.Popup(edtTime.Handle, ttWarningIcon, '��ʾ', 'ʱ���ʽ����!');
    Exit;
  end;

  isAdd := not Assigned(FTask);
  if isAdd then
  begin
    FTask := g_TaskMgr.NewTask(True);
    Item := g_TaskMgr.Lv.Items.Insert(0);
    g_TaskMgr.UpdateTaskCount;
  end
  else
    Item := FTask.ItemUI;

  FTask.Active := chkActive.Checked;
  FTask.CId := Integer(cbbClass.Items.Objects[cbbClass.ItemIndex]);
  FTask.TaskType := TTaskType(cbbType.ItemIndex);
  FTask.ExecNum := seExecNum.Value;
  FTask.TimeType := timeType;
  FTask.TimeRec := timeRec;
  FTask.Param := edtParam.Text;
  FTask.Content := mmoContent.Text;
  FTask.TmpExecNum := chkTmpExecNum.Checked;
  FTask.Update;
  FTask.ResetLoop;
  FTask.AssignUI(Item);

  Close;
end;

procedure TfrmAddTask.chkEveryDayClick(Sender: TObject);
begin
  if Self.Showing then
    FToolTip.EndPopup;

  { ��ʼ״̬ }
  chkLoop.Enabled := not (chkEveryDay.Checked or chkMonthly.Checked);
  chkMonthly.Enabled := not (chkEveryDay.Checked or chkLoop.Checked);
  chkEveryDay.Enabled := not (chkLoop.Checked or chkMonthly.Checked);
  chkWeek.Enabled := chkEveryDay.Checked or chkLoop.Checked;
  if not chkWeek.Enabled then
    chkWeek.Checked := False;

  if chkLoop.Checked then
  begin                                 { ѭ�� }
    edtTime.Text := '60';
    edtTime.MaxLength := 9;             //999 999 999 < MAX_DWORD
    SetWindowLong(edtTime.Handle, GWL_STYLE,
      GetWindowLong(edtTime.Handle, GWL_STYLE) or ES_NUMBER);

    if Self.Showing then
      FToolTip.Popup(edtTime.Handle, ttInformationIcon, '��ʾ', '���뵹��ʱ��(��)');
  end
  else
  begin
    SetWindowLong(edtTime.Handle, GWL_STYLE,
      GetWindowLong(edtTime.Handle, GWL_STYLE) and not ES_NUMBER);

    if chkEveryDay.Checked then
    begin                               { ÿ�� }
      edtTime.Text := FormatDateTime(DATETIME_FORMAT_SETTINGS.LongTimeFormat, now);
      edtTime.MaxLength := 8;
    end
    else if chkMonthly.Checked then
    begin                               { ÿ�� }
      edtTime.Text := FormatDateTime('dd hh:mm:ss', now);
      edtTime.MaxLength := 11;
    end
    else
    begin                               { ���� }
      edtTime.Text := FormatDateTime(DATETIME_FORMAT_SETTINGS.LongDateFormat, now);
      edtTime.MaxLength := 19;
    end;
  end;
end;

procedure TfrmAddTask.chkWeekClick(Sender: TObject);
begin
  { ���� }
  chkMon.Enabled := chkWeek.Checked;
  chkTue.Enabled := chkWeek.Checked;
  chkWed.Enabled := chkWeek.Checked;
  chkThu.Enabled := chkWeek.Checked;
  chkFri.Enabled := chkWeek.Checked;
  chkSat.Enabled := chkWeek.Checked;
  chkSun.Enabled := chkWeek.Checked;

  if chkWeek.Checked then
  begin
    if not chkLoop.Enabled and not chkEveryDay.Enabled then
    begin                               { ��������ģʽ }
      chkLoop.Enabled := True;
      chkEveryDay.Enabled := True;
    end;
  end;
end;

procedure TfrmAddTask.cbbTypeChange(Sender: TObject);
var
  s                 : string;
  tt                : TTaskType;
begin
  tt := TTaskType(TComboBox(Sender).ItemIndex);

  if tt in [ttSendEmail] then
    lblParam.Caption := '����:'
  else
    lblParam.Caption := '��ע:';

  if tt in [ttExec, ttParamExec, ttCmdExec] then
    FParamTip := HIDE_PARAM_HEAD + ' ��ͷ����ִ�д�����!'
  else
    FParamTip := '';

  if tt in [ttExec, ttParamExec, ttDownExec, ttKillProcess, ttWakeUp] then
    FContentTip := 'ÿ��ִ��һ�Σ�'
  else if tt in [ttShutdownSys, ttRebootSys, ttLogoutSys, ttLockSys,
    ttSuspendSys] then
    FContentTip := '��ͷΪ���֣�ִ��ʱ��ʾ���ȴ�n��'
  else
    FContentTip := '';

  s := '����:'#13#10;
  case tt of
    ttExec:
      s := s
        + 'http://www.yryz.net'#13#10
        + 'd:\mp3\alarm.mp3';

    ttParamExec:
      s := s
        + 'ping 127.0.0.1'#13#10
        + 'shutdown -s';

    ttDownExec:
      s := s
        + 'http://im.qq.com/qq.exe';

    ttKillProcess:
      s := s
        + 'qq.exe'#13#10
        + 'cmd.exe';

    ttWakeUp:
      s := s
        + '00-e0-4d-df-7e-8a'#13#10
        + '00-e0-4d-df-88-1c';

    ttCmdExec:
      s := s
        + 'del c:\*.log'#13#10
        + 'mkdir c:\s'#13#10
        + 'systeminfo > c:\s\s.txt';

    ttMsgTip:
      s := s
        + '��˯����~~��';

    ttSendEmail:
      s := s
        + '�ļ�'#13#10
        + 'c:\s\s.txt'#13#10
        + '����'#13#10
        + 'SMTP Test!';

    ttSendKey:
      s := s
        + '^%z'#13#10
        + 'ģ�� Ctrl+Alt+Z';

    ttShutdownSys,
      ttRebootSys,
      ttLogoutSys,
      ttLockSys,
      ttSuspendSys:
      s := s
        + '30�뵹��ʱ...';
  end;

  mmoContent.Hint := s;
  if mmoContent.Enabled then
    mmoContent.Color := clWindow
  else
    mmoContent.Color := clBtnFace;
end;

procedure TfrmAddTask.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  //����ϵͳ��Ϣ��֪ͨ���ڱ����������£�֮��Ϳ�������
  SendMessage(Handle, WM_SYSCOMMAND, $F012, 0);
end;

procedure TfrmAddTask.FormPaint(Sender: TObject);
begin
  DrawRoundForm(Handle, Width, Height, $00CD746D);
end;

procedure TfrmAddTask.mmoContentEnter(Sender: TObject);
begin
  if Self.Showing and (FContentTip <> '') then
    FToolTip.Popup(TWinControl(Sender).Handle, ttInformationIcon, '��ʾ', FContentTip);
end;

procedure TfrmAddTask.edtParamEnter(Sender: TObject);
begin
  if Self.Showing and (FParamTip <> '') then
    FToolTip.Popup(TWinControl(Sender).Handle, ttInformationIcon, '��ʾ', FParamTip);
end;

procedure TfrmAddTask.mmoContentExit(Sender: TObject);
begin
  FToolTip.EndPopup;
end;

end.

