program OnTime;

uses
  Forms,
  SysUtils,
  frmOnTime_u in 'frmOnTime_u.pas' {frmOnTime},
  frmAddTask_u in 'frmAddTask_u.pas' {frmAddTask},
  frmOption_u in 'frmOption_u.pas' {frmOption},
  frmAbout_u in 'frmAbout_u.pas' {frmAbout},
  TaskMgr_u in 'TaskMgr_u.pas',
  TooltipUtil in 'TooltipUtil.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '����ƻ�';
  if StrIComp(PChar(ParamStr(1)), '/hide') = 0 then
    Application.ShowMainForm := False;
  Application.CreateForm(TfrmOnTime, frmOnTime);
  Application.Run;
end.

