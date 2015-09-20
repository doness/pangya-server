unit ServerClient;

interface

uses Client, Buffer, ScktComp, CryptLib;

type
  TServerClient<ClientType> = class (TClient<ClientType>)
    private
      var m_buffin: TBuffer;
    public
      constructor Create(Socket: TCustomWinSocket; cryptLib: TCryptLib);
      destructor Destroy; override;
      function GetBuffin: TBuffer;
      function HasSocket(Socket: TCustomWinSocket): Boolean;
      function GetBuffout: TBuffer;
      procedure ReceiveData(data: AnsiString);
      procedure HandleSend;
  end;

implementation

uses ConsolePas;

procedure TServerClient<ClientType>.ReceiveData(data: AnsiString);
begin
  m_buffin.Write(data);
end;

constructor TServerClient<ClientType>.Create(Socket: TCustomWinSocket; cryptLib: TCryptLib);
begin
  inherited;
  m_buffin := TBuffer.Create;
end;

destructor TServerClient<ClientType>.Destroy;
begin
  inherited;
  m_buffin.Free;
end;

function TServerClient<ClientType>.GetBuffin: TBuffer;
begin
  Result := m_buffin;
end;

procedure TServerClient<ClientType>.handleSend;
var
  y: integer;
begin
  if (m_buffout.GetLength > 0) then
  begin
    y := m_socket.SendText(m_buffout.GetData);
    m_buffout.Delete(0, y);
  end;
end;

function TServerClient<ClientType>.HasSocket(Socket: TCustomWinSocket): Boolean;
begin
  Result := m_socket = Socket;
end;

function TServerClient<ClientType>.GetBuffout: TBuffer;
begin
  Result := m_buffout;
end;

end.
