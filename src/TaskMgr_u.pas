unit TaskMgr_u;

interface
uses
  Windows, SysUtils, Classes, Graphics, ExtCtrls, ComCtrls,
  ShellAPI, SQLite3, SQLiteTable3;

type
  TTaskType = (ttExec, ttParamExec, ttDownExec, ttKillProcess, ttCmdExec,
    ttSendKey, ttSendEmail, ttWakeUp, ttMsgTip, ttShutdownPC, ttRebootPC,
    ttLogoutPC, ttLockPC);
const
  ONTIME_DB         = 'OnTime.db';
  ONTIME_DB_KEY     = '';
  TASK_TYPE_STR     : array[TTaskType] of string[8] =
    ('��ͨ����', '��������', '��������', '��������', 'ִ��DOS', 'ģ�ⰴ��',
    '�����ʼ�', '���绽��', '��Ϣ��ʾ', '�ر�ϵͳ', '����ϵͳ', 'ע����½',
    '����ϵͳ');

  { OPTION SQL }
  SQL_CREATE_OPTION = 'CREATE TABLE option(smtpserver TEXT,smtpport INTEGER,'
    + 'smtpuser TEXT,smtppass TEXT)';
  SQL_INSERT_OPTION = 'INSERT INTO option(smtpserver,smtpport,smtpuser,smtppass'
    + ') VALUES("smtp.126.com",25,"ontimer","")';
  SQL_UPDATE_OPTION = 'UPDATE option SET smtpserver=?,smtpport=?,smtpuser=?'
    + ',smtppass=?';
  { TASK SQL }
  SQL_CREATE_TASKLIST = 'CREATE TABLE tasklist(id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,'
    + 'checked INTEGER,tasktype INTEGER,timetype INTEGER,time INTEGER,content TEXT,'
    + 'param TEXT,execnum INTEGER)';
  SQL_SELECT_OPTION = 'SELECT * FROM option';
  SQL_SELECT_TASKLIST = 'SELECT * FROM tasklist';
  SQL_INSERT_TASK   = 'INSERT INTO tasklist(checked,tasktype,timetype,time,'
    + 'content,param,execnum) VALUES(?,?,?,?,?,?,?)';
  SQL_UPDATE_TASK   = 'UPDATE tasklist SET checked=?,tasktype=?,timetype=?,time=?,'
    + 'content=?,param=?,execnum=? WHERE id=';
  SQL_UPDATE_TASK2  = 'UPDATE tasklist SET checked=? WHERE id=';
  SQL_DELETE_TASK   = 'DELETE FROM tasklist WHERE id=';

type
  TTimeType = (ttDateTime, ttTime, ttLoop, ttWeekOfTime, ttWeekOfLoop);
  TWeekOfDay = (wdNone, wdMon, wdTue, wdWed, wdThu, wdFri, wdSat, wdSun);
  PWeekSet = ^TWeekSet;
  TWeekSet = set of TWeekOfDay;
  PTimeRec = ^TTimeRec;
  TTimeRec = record                     //Ҫ��TTimeStamp�ṹ��ͬ��
    TimeOrLoop: DWORD;
    DateOrWeek: DWORD;
  end;

type
  TTaskMgr = class;

  PTask = ^TTask;
  TTask = class(TListItem)              //TListView����Ӵ�Item
  private
    FId: Integer;
    FExecNum: DWORD;                    //��ִ�д���
    FTaskType: TTaskType;
    FTimeType: TTimeType;               //��ʱ����
    FLoopTime: DWORD;                   //����ʱ����
    FIsWeek: Boolean;                   //�Ƿ��������жϣ�ֻ��ʱ�䡢����ʱ��Ч
    FWeekStr: string;
    FTimeRec: TTimeRec;                 //�趨���ڡ�ʱ�䡢���ڡ�����ʱ
    FParam: string;
    FContent: string;
    FLastChecked: Boolean;              //�����Ƿ�Ҫ��Checked״̬д�����ݿ�
    procedure SetContent(const Value: string);
    procedure SetParam(const Value: string);
    procedure SetTaskType(const Value: TTaskType);
    procedure SetExecNum(const Value: DWORD);
  public
    constructor Create(Items: TListItems);
    destructor Destroy; override;
    procedure Execute;
    function DecLoop: Integer;          //����һ�Σ���һ��
    procedure SetTime(timeType: TTimeType; Value: TTimeRec);
  published
    property Id: Integer read FId write FId;
    property ExecNum: DWORD read FExecNum write SetExecNum;
    property TaskType: TTaskType read FTaskType write SetTaskType;
    property TimeType: TTimeType read FTimeType;
    property IsWeek: Boolean read FIsWeek;
    property TimeRec: TTimeRec read FTimeRec write FTimeRec;
    property Param: string read FParam write SetParam;
    property Content: string read FContent write SetContent;
    property LastChecked: Boolean read FLastChecked write FLastChecked;
  end;

  TTaskMgr = class
  private
    FItems: TListItems;
    FTaskDB: TSQLiteDatabase;
    procedure LoadTask;
  public
    constructor Create(lvTask: TListView);
    destructor Destroy; override;
    function Make(bChecked: Boolean): TTask;
    procedure Update(isAdd: Boolean; Task: TTask);
    procedure UpdateCheckState(Task: TTask);
    procedure UpdateOption;
    function DeleteSelected: Integer;
    procedure OnTimer(dateTime: TDateTime);
  end;

  TSMTPOption = record
    Server: string;
    Port: Word;
    UserName: string;
    Password: string;
  end;

var
  g_SMTPOption      : TSMTPOption;
  g_TaskMgr         : TTaskMgr;

const
  DOUBLE_MAGIC      = 6755399441055744.0; //Double + 1.5*2^52
  MAX_LOOP_VALUE    = $3FFFFF;          //DOUBLE_MAGIC ֻ�ܴ����� 23λ

function FloatToInt23(Value: double): Integer;

implementation
uses
  sndkey32, FuncLib, Proc_u, PopTooltip_u;

function FloatToInt23(Value: double): Integer;
var
  d                 : Double;
begin
  d := Value + DOUBLE_MAGIC;
  Result := PInteger(@d)^;
end;

{ TTask }

constructor TTask.Create;
begin
  inherited Create(Items);
  SubItems.Add('');                     //ʱ��
  SubItems.Add('');                     //����
  SubItems.Add('');                     //����
  SubItems.Add('');                     //���Ӳ���
  SubItems.Add('');                     //��ִ�д���
  Data := Self;
end;

destructor TTask.Destroy;
begin
  inherited;
end;

procedure TTask.Execute;
var
  dwThID            : DWORD;
begin
  case FTaskType of
    ttExec:
      ShellExecute(0, nil, PChar(FContent), nil, nil, SW_SHOW); //����
    ttParamExec:
      WinExec(PChar(FContent), SW_SHOW);
    ttDownExec:
      CloseHandle(BeginThread(nil, 0, @DownloadExec, PChar(FContent), 0, dwThID));
    ttKillProcess: begin
        SetPrivilege('SeDebugPrivilege');
        KillTask(PChar(FContent));
      end;
    ttCmdExec:
      WinExec(PChar('cmd /c ' + FContent), SW_SHOW);
    ttSendKey:
      SendKeys(PChar(FContent), False);
    ttSendEmail:
      CloseHandle(BeginThread(nil, 0, @SendMail, Self, 0, dwThID));
    ttWakeUp:
      WakeUpPro(FContent);
    ttMsgTip:
      TPopTooltip.ShowMsg(FContent,
        ExtractFilePath(ParamStr(0)) + 'OnTime.jpg', 10 * 1000);
    ttShutdownPC: begin
        SetPrivilege('SeShutdownPrivilege');
        ExitWindowsEX(EWX_SHUTDOWN or EWX_FORCE, 0); {�ػ�}
      end;
    ttRebootPC: begin
        SetPrivilege('SeShutdownPrivilege');
        ExitWindowsEX(EWX_REBOOT or EWX_FORCE, 0); {����}
      end;
    ttLogoutPC: begin
        SetPrivilege('SeShutdownPrivilege');
        ExitWindowsEX(EWX_LOGOFF or EWX_FORCE, 0); {ע��}
      end;
    ttLockPC: LockWorkStation;
  end;

  ImageIndex := 1;
  if FExecNum > 0 then
    SetExecNum(FExecNum - 1);
end;

function TTask.DecLoop;
begin
  Dec(FLoopTime);
  Result := FLoopTime;
  Caption := FWeekStr + IntToStr(Result);
  if Result <= 0 then
    FLoopTime := FTimeRec.TimeOrLoop;
end;

procedure TTask.SetTime;
var
  weekSet           : TWeekSet;
begin
  FTimeRec := Value;
  FTimeType := timeType;
  case timeType of
    {���̶����ڡ�}
    ttDateTime: Caption := FormatDateTime('yyyy-MM-dd hh:mm:ss', PDateTime(@Value)^);
    {������ʱ�䡡}
    ttLoop, ttTime: begin
        weekSet := PWeekSet(@Value.DateOrWeek)^;
        FIsWeek := TWeekOfDay(weekSet) > wdNone; { ��һ������ }
        if FIsWeek then begin
          FWeekStr := '';
          if wdMon in weekSet then FWeekStr := FWeekStr + '1#';
          if wdTue in weekSet then FWeekStr := FWeekStr + '2#';
          if wdWed in weekSet then FWeekStr := FWeekStr + '3#';
          if wdThu in weekSet then FWeekStr := FWeekStr + '4#';
          if wdFri in weekSet then FWeekStr := FWeekStr + '5#';
          if wdSat in weekSet then FWeekStr := FWeekStr + '6#';
          if wdSun in weekSet then FWeekStr := FWeekStr + '7#';
        end;
        if FTimeType = ttLoop then begin
          FLoopTime := Value.TimeOrLoop;
          Caption := FWeekStr + IntToStr(FLoopTime);
        end else
          Caption := FWeekStr + FormatDateTime('hh:mm:ss', PDateTime(@Value)^);
      end;
  end;
end;

procedure TTask.SetContent(const Value: string);
begin
  FContent := Value;
  SubItems.Strings[1] := Value;
end;

procedure TTask.SetParam(const Value: string);
begin
  FParam := Value;
  SubItems.Strings[2] := Value;
end;

procedure TTask.SetTaskType(const Value: TTaskType);
begin
  FTaskType := Value;
  SubItems.Strings[0] := TASK_TYPE_STR[Value];
end;

procedure TTask.SetExecNum(const Value: DWORD);
begin
  FExecNum := Value;
  SubItems.Strings[3] := IntToStr(Value);
end;

{ TTaskMgr }

constructor TTaskMgr.Create;
begin
  FItems := lvTask.Items;
  LoadTask;
end;

destructor TTaskMgr.Destroy;
var
  I                 : Integer;
begin
  if FItems.Count > 0 then
    for i := FItems.Count - 1 downto 0 do
      with FItems[i] do begin
        TTask(Data).Free;
        Delete();
      end;
  if Assigned(FTaskDB) then FTaskDB.Free;
  inherited;
end;

function TTaskMgr.Make;
begin
  Result := TTask.Create(FItems);
  FItems.AddItem(Result);
  Result.Checked := bChecked;
  Result.LastChecked := bChecked;
end;

procedure TTaskMgr.Update;
var
  sql               : string;
  Table             : TSQLiteTable;
begin
  if isAdd then
    sql := SQL_INSERT_TASK
  else
    sql := SQL_UPDATE_TASK + IntToStr(Task.Id);
  try
    Table := TSQLiteTable.Create(FTaskDB, sql, [Task.Checked,
      Integer(Task.TaskType), Integer(Task.TimeType), PInt64(@Task.TimeRec)^,
        Task.Content, Task.Param, Task.ExecNum]);
    if isAdd then
      Task.Id := FTaskDB.GetLastInsertRowID;
  finally
    Table.Free;
  end;
end;

procedure TTaskMgr.UpdateCheckState(Task: TTask);
var
  Table             : TSQLiteTable;
begin
  try
    Task.LastChecked := not Task.LastChecked;
    Table := TSQLiteTable.Create(FTaskDB, SQL_UPDATE_TASK2 + IntToStr(Task.Id),
      [Task.Checked]);
  finally
    Table.Free;
  end;
end;

procedure TTaskMgr.UpdateOption;
var
  Table             : TSQLiteTable;
begin
  try
    Table := TSQLiteTable.Create(FTaskDB, SQL_UPDATE_OPTION, [g_SMTPOption.Server,
      g_SMTPOption.Port, g_SMTPOption.UserName, g_SMTPOption.Password]);
  finally
    Table.Free;
  end;
end;

function TTaskMgr.DeleteSelected;
var
  i                 : Integer;
begin
  Result := -1;
  if FItems.Count < 1 then Exit;

  for i := FItems.Count - 1 downto 0 do
    with FItems[i] do
      if Selected then begin
        if Assigned(FTaskDB) then
          FTaskDB.ExecSQL(SQL_DELETE_TASK + IntToStr(TTask(Data).FId));
        Delete;
        Result := i;
      end;
end;

procedure TTaskMgr.OnTimer;
var
  i                 : Integer;
  Task              : TTask;
  time1, time2      : TTimeStamp;
begin
  if FItems.Count < 1 then Exit;

  for i := 0 to FItems.Count - 1 do begin
    Task := FItems[I].Data;
    if not Task.Checked or
      (Integer(Task.ExecNum) < 1) then Continue; //����ִ��

    case Task.TimeType of
      ttDateTime: begin                 //����ʱ��
          time1 := DateTimeToTimeStamp(dateTime);
          time2 := TTimeStamp(Task.TimeRec);
          if (time1.Date <> time1.Date) or
            (time1.Time div MSecsPerSec <> time2.Time div MSecsPerSec) then
            Continue;
        end;
      ttLoop, ttTime: begin
          time1 := DateTimeToTimeStamp(dateTime);
          if Task.IsWeek then           { ���� }
            if not (TWeekOfDay(time1.Date mod 7 + 1) in
              PWeekSet(@Task.TimeRec.DateOrWeek)^) then
              Continue;
              
          if Task.TimeType = ttLoop then begin //����ʱ��
            if Task.DecLoop > 0 then Continue;
          end else
          begin                         //ʱ��
            time2 := TTimeStamp(Task.TimeRec);
            if time1.Time div MSecsPerSec <> time2.Time div MSecsPerSec then
              Continue;
          end;
        end;
    end;

    Task.Execute;
  end;
end;

procedure TTaskMgr.LoadTask;
var
  i                 : Integer;
  Task              : TTask;
  Table             : TSQLiteTable;
begin
  try
    if not FileExists(ONTIME_DB) then begin
      FTaskDB := TSQLiteDatabase.Create(ONTIME_DB, ONTIME_DB_KEY); //ʹ�����봴�����ݿ�
      FTaskDB.BeginTransaction;
      FTaskDB.ExecSQL(SQL_CREATE_OPTION);
      FTaskDB.ExecSQL(SQL_INSERT_OPTION);
      FTaskDB.ExecSQL(SQL_CREATE_TASKLIST);
      FTaskDB.Commit;
    end else begin
      FTaskDB := TSQLiteDatabase.Create(ONTIME_DB, ONTIME_DB_KEY); //ʹ����������ݿ�
      try
        Table := TSQLiteTable.Create(FTaskDB, SQL_SELECT_OPTION, []);
        if Table.RowCount > 0 then begin
          g_SMTPOption.Server := Table.FieldAsString(0);
          g_SMTPOption.Port := Table.FieldAsInteger(1);
          g_SMTPOption.UserName := Table.FieldAsString(2);
          g_SMTPOption.Password := Table.FieldAsString(3);
        end;
        Table.Free;

        Table := TSQLiteTable.Create(FTaskDB, SQL_SELECT_TASKLIST, []);
        with Table do
          for i := 0 to RowCount - 1 do
          begin
            Task := Self.Make(Boolean(FieldAsInteger(1)));
            Task.Id := FieldAsInteger(0);
            Task.TaskType := TTaskType(FieldAsInteger(2));
            Task.SetTime(TTimeType(FieldAsInteger(3)), TTimeRec(FieldAsInteger(4)));
            Task.Content := FieldAsString(5);
            Task.Param := FieldAsString(6);
            Task.ExecNum := FieldAsInteger(7);
            Next;
          end;
      finally
        Table.Free;
      end;
    end;
  except
    on E: Exception do begin
      OutDebug('TTaskMgr.LoadTask Except! Exit!' + e.Message);
      MessageBox(0, PChar('��ȡ���ݿ� ' + ONTIME_DB + ' �쳣��'#13#10#13#10
        + '���Գ���ɾ�����ļ�.Ҳ�����ҷ�������Ϣ��'), '��ʾ', MB_ICONWARNING);
      PostQuitMessage(0);               //�˳�
    end;
  end;
end;


end.

