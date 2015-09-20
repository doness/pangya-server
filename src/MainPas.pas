unit MainPas;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, LoginServer, Server, Logging, CryptLib,
  gameServer;

type
  TMain = class(TForm)
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    var m_loginServer: TLoginServer;
    var m_gameServer: TGameServer;
    var m_cryptLib: TCryptLib;
    procedure OnServerLog(sender: TObject; msg: string; logType: TLogType);
  public
  end;

var
  Main: TMain;

implementation

{$R *.dfm}

uses ConsolePas;

procedure TMain.FormDestroy(Sender: TObject);
begin
  m_loginServer.Free;
  m_cryptLib.Free;
  m_gameServer.Free;
end;

procedure TMain.FormShow(Sender: TObject);
begin
  Console.Show;
  Console.Log('PANGYA SERVER by HSReina', C_GREEN);

  m_cryptLib:= TCryptLib.Create;

  m_loginServer := TLoginServer.Create(m_cryptLib);
  m_gameServer := TGameServer.Create(m_cryptLib);

  if not m_cryptLib.init then
  begin
    Console.Log('CryptLib init Failed', C_RED);
    Exit;
  end else
  begin
    Console.Log('CryptLib init Ok', C_GREEN);
  end;

  m_loginServer.OnLog := self.OnServerLog;
  m_gameServer.OnLog := self.OnServerLog;
  m_loginServer.Start;
  m_gameServer.Start;
end;

procedure TMain.OnServerLog(sender: TObject; msg: string; logType: TLogType);
var
  color: integer;
begin

  case logType of
    TLogType_msg: ;
    TLogType_wrn: color := C_ORANGE;
    TLogType_err: color := C_RED;
    TLogType_not: color := C_BLUE;
  end;

  Console.Log(msg, color);
end;

end.
