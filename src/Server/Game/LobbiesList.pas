{*******************************************************}
{                                                       }
{       Pangya Server                                   }
{                                                       }
{       Copyright (C) 2015 Shad'o Soft tm               }
{                                                       }
{*******************************************************}

unit LobbiesList;

interface

uses
  Generics.Collections, Lobby, PacketData, GameServerPlayer, Game;

type

  TLobbyList = TList<TLobby>;

  TLobbiesList = class
    protected
    private
      var m_lobbies: TLobbyList;
      procedure DestroyLobbies;
    public
      constructor Create;
      destructor Destroy; override;
      function GetLobbyById(const lobbyId: Byte): TLobby;
      function GetPlayerLobby(const player: TGameClient): TLobby;
      function TryGetPlayerLobby(const player: TGameClient; var lobby: TLobby): Boolean;
      function GetPlayerGame(const player: TGameClient): TGame;
      procedure Send(const data: AnsiString);
      function Build: TPacketData;
  end;

implementation

uses GameServerExceptions;

constructor TLobbiesList.Create;
var
  lobby: TLobby;
  index: integer;
begin
  inherited;
  m_lobbies := TLobbyList.Create;
  lobby := TLobby.Create;
  lobby.Id := m_lobbies.Add(lobby);
end;

destructor TLobbiesList.Destroy;
begin
  inherited;
  DestroyLobbies;
  m_lobbies.Free;
end;

procedure TLobbiesList.DestroyLobbies;
var
  lobby: TLobby;
begin
  for lobby in m_lobbies do
  begin
    lobby.Free;
  end;
end;

function TLobbiesList.GetLobbyById(const lobbyId: Byte): TLobby;
var
  lobby: TLobby;
begin
  for lobby in m_lobbies do
  begin
    if lobby.Id = lobbyId then
    begin
      Exit(lobby);
    end;
  end;
  raise LobbyNotFoundException.Create('Lobby not found');
end;

function TLobbiesList.GetPlayerLobby(const player: TGameClient): TLobby;
begin
  Exit(self.GetLobbyById(player.Data.Lobby));
end;

function TLobbiesList.TryGetPlayerLobby(const player: TGameClient; var lobby: TLobby): Boolean;
begin
  try
    lobby := GetPlayerLobby(player);
  except
    Exit(False);
  end;
  Exit(True);
end;

function TLobbiesList.GetPlayerGame(const player: TGameClient): TGame;
var
  lobby: TLobby;
begin
  lobby := self.GetLobbyById(player.Data.Lobby);
  Exit(lobby.GetPlayerGame(player));
end;

function TLobbiesList.Build: TPacketData;
var
  lobby: TLobby;
begin
  Result := #$4D#$00 + #$01;
  for lobby in m_lobbies do
  begin
    Result := Result + lobby.Build;
  end;
end;

procedure TLobbiesList.Send(const data: AnsiString);
var
  lobby: TLobby;
begin
  for lobby in m_lobbies do
  begin
    lobby.Send(data);
  end;
end;

end.
