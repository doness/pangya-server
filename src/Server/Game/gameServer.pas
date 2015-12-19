unit GameServer;

interface

uses Client, GameServerPlayer, Server, ClientPacket, SysUtils, LobbiesList, CryptLib,
  SyncableServer, PangyaBuffer, PangyaPacketsDef, Lobby, Game;

type

  TGameClient = TClient<TGameServerPlayer>;

  TGameServer = class (TSyncableServer<TGameServerPlayer>)
    protected
    private
      procedure Init; override;
      procedure OnClientConnect(const client: TGameClient); override;
      procedure OnClientDisconnect(const client: TGameClient); override;
      procedure OnReceiveClientData(const client: TGameClient; const clientPacket: TClientPacket); override;
      procedure OnReceiveSyncData(const clientPacket: TClientPacket); override;
      procedure OnDestroyClient(const client: TGameClient); override;
      procedure OnStart; override;

      procedure Sync(const client: TGameClient; const clientPacket: TClientPacket); overload;
      procedure PlayerSync(const clientPacket: TClientPacket; const client: TGameClient);
      procedure ServerPlayerAction(const clientPacket: TClientPacket; const client: TGameClient);

      var m_lobbies: TLobbiesList;

      function LobbiesList: AnsiString;

      procedure HandleLobbyRequests(const lobby: TLobby; const packetId: TCGPID; const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandleGameRequests(const game: TGame; const packetId: TCGPID; const client: TGameClient; const clientPacket: TClientPacket);

      procedure HandlePlayerLogin(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandleDebugCommands(const client: TGameClient; const clientPacket: TClientPacket; msg: AnsiString);
      procedure HandlePlayerSendMessage(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerJoinLobby(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerCreateGame(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerJoinGame(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerLeaveGame(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerBuyItem(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerRequestIdentity(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerRequestServerList(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerUpgrade(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerNotice(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerChangeEquipment(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerAction(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerJoinMultiplayerGamesList(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerLeaveMultiplayerGamesList(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerOpenRareShop(const client: TGameClient; const clientPacket: TClientPacket);
      procedure handlePlayerRequestMessengerList(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerGMCommaand(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerUnknow00EB(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerOpenScratchyCard(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerSetAssistMode(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerUnknow0140(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerRequestAchievements(const client: TGameClient; const clientPacket: TClientPacket);
      procedure PlayerRequestDailyReward(const client: TGameClient; const clientPacket: TClientPacket);
      procedure HandlePlayerRequestInfo(const client: TGameClient; const clientPacket: TClientPacket);

      procedure SendToGame(const client: TGameClient; data: AnsiString); overload;
      procedure SendToGame(const client: TGameClient; data: TPangyaBuffer); overload;
      procedure SendToLobby(const client: TGameClient; data: AnsiString); overload;
      procedure SendToLobby(const client: TGameClient; data: TPangyaBuffer); overload;

    public
      constructor Create(cryptLib: TCryptLib);
      destructor Destroy; override;
  end;

implementation

uses Logging, ConsolePas, Buffer, utils, PacketData, defs,
        PlayerCharacter, GameServerExceptions,
  PlayerAction, Vector3, PlayerData;

constructor TGameServer.Create(cryptLib: TCryptLib);
begin
  inherited;
  Console.Log('TGameServer.Create');
  m_lobbies:= TLobbiesList.Create;
end;

destructor TGameServer.Destroy;
begin
  inherited;
  m_lobbies.Free;
end;

function TGameServer.LobbiesList: AnsiString;
begin
  Result := m_lobbies.Build;
end;

procedure TGameServer.Init;
begin
  self.SetPort(7997);
  self.SetSyncPort(7998);
  self.setSyncHost('127.0.0.1');
end;

procedure TGameServer.OnClientConnect(const client: TGameClient);
var
  player: TGameServerPlayer;
begin
  self.Log('TGameServer.OnConnectClient', TLogType_not);
  player := TGameServerPlayer.Create;
  client.Data := player;
  client.Send(
    #$00#$16#$00#$00#$3F#$00#$01#$01 +
    AnsiChar(client.GetKey()) +
    // no clue about that.
    WritePStr(client.Host),
    false
  );
end;

procedure TGameServer.OnClientDisconnect(const client: TGameClient);
var
  lobby: TLobby;
begin
  self.Log('TGameServer.OnDisconnectClient', TLogType_not);
  try
    lobby := m_lobbies.GetLobbyById(client.Data.Lobby);
    lobby.RemovePlayer(client);
  Except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
    end;
  end;
end;

procedure TGameServer.OnStart;
begin
  self.Log('TGameServer.OnStart', TLogType_not);
  self.StartSyncClient;
end;

procedure TGameServer.Sync(const client: TGameClient; const clientPacket: TClientPacket);
begin
  self.Log('TGameServer.Sync', TLogType.TLogType_not);
  self.Sync(#$02 + #$01#$00 + write(client.UID.id, 4) + writePStr(client.UID.login) + clientPacket.ToStr);
end;

procedure TGameServer.HandlePlayerLogin(const client: TGameClient; const clientPacket: TClientPacket);
var
  login: AnsiString;
begin
  self.Log('TGameServer.HandlePlayerLogin', TLogType_not);
  clientPacket.ReadPStr(login);
  client.UID.login := login;
  client.UID.id := 0;
  self.Sync(client, clientPacket);
end;

procedure TGameServer.HandleDebugCommands(const client: TGameClient; const clientPacket: TClientPacket; msg: AnsiString);
var
  game: TGame;
begin

  game := self.m_lobbies.GetPlayerGame(client);

  // Speed ugly way for debug command
  if msg = ':debug' then
  begin
    game.HandlePlayerStartGame(client, clientPacket);
  end
  else if msg = ':next' then
           
  begin
    game.GoToNextHole;
  end;


end;

procedure TGameServer.HandlePlayerSendMessage(const client: TGameClient; const clientPacket: TClientPacket);
var
  login: AnsiString;
  msg: AnsiString;
  reply: TPangyaBuffer;
begin
  Console.Log('TGameeServer.HandlePlayerSendMessage', C_BLUE);
  clientPacket.ReadPStr(login);
  clientPacket.ReadPStr(msg);

  reply := TPangyaBuffer.Create;
  reply.WriteStr(#$40#$00 + #$00);
  reply.WritePStr(login);
  reply.WritePStr(msg);

  if (Length(msg) >= 1) and (msg[1] = ':') then
  begin
    self.HandleDebugCommands(client, clientPacket, msg);
    Exit;
  end;

  SendToGame(client, reply);

  reply.Free;
end;

procedure TGameServer.HandlePlayerJoinLobby(const client: TGameClient; const clientPacket: TClientPacket);
var
  lobbyId: UInt8;
  lobby: TLobby;
begin
  self.Log('TGameServer.HandlePlayerJoinLobby', TLogType_not);

  if false = clientPacket.ReadUInt8(lobbyId) then
  begin
    Console.Log('Failed to read lobby id', C_RED);
    Exit;
  end;

  try
    lobby := m_lobbies.GetLobbyById(lobbyId);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  lobby.AddPlayer(client);

  client.Send(#$95#$00 + AnsiChar(lobbyId) + #$01#$00);
  client.Send(#$4E#$00 + #$01);
end;

procedure TGameServer.HandlePlayerCreateGame(const client: TGameClient; const clientPacket: TClientPacket);
var
  gameInfo: TPlayerCreateGameInfo;
  gameName: AnsiString;
  gamePassword: AnsiString;
  artifact: UInt32;
  playerLobby: TLobby;
  game: TGame;
  currentGame: Tgame;
  d: AnsiString;
begin
  Console.Log('TGameServer.HandlePlayerCreateGame', C_BLUE);
  clientPacket.Read(gameInfo.un1, SizeOf(TPlayerCreateGameInfo));

  clientPacket.ReadPStr(gameName);
  clientPacket.ReadPStr(gamePassword);
  clientPacket.ReadUInt32(artifact);

  try
    playerLobby := m_lobbies.GetPlayerLobby(client);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  try
    game := playerLobby.CreateGame(gamename, gamePassword, gameInfo, artifact);
    currentGame := m_lobbies.GetPlayerGame(client);
    currentGame.RemovePlayer(client);
    game.AddPlayer(client);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  // result
  client.Send(
    #$4A#$00 +
    #$FF#$FF +
    game.GameResume
  );

  // game game informations
  client.Send(
    #$49#$00 +
    #$00#$00 +
    game.GameInformation
  );

  // my player game info
  client.Send(
    #$48#$00#$00#$FF#$FF#$01 +
    client.Data.GameInformation +
    #$00
  );

  // Lobby player informations
  client.Send(
    #$46#$00#$03#$01 +
    client.Data.LobbyInformations
  );
end;

procedure TGameServer.HandlePlayerJoinGame(const client: TGameClient; const clientPacket: TClientPacket);
var
  gameId: UInt16;
  password: AnsiString;
  game: TGame;
  playerLobby: TLobby;
begin
  Console.Log('TGameServer.HandlePlayerJoinGame', C_BLUE);
  {09 00 01 00 00 00  }
  if not clientPacket.ReadUInt16(gameId) then
  begin
    Console.Log('Failed to get game Id', C_RED);
    Exit;
  end;
  clientPacket.ReadPStr(password);

  try
    playerLobby := m_lobbies.GetPlayerLobby(client);
    game := playerLobby.GetGameById(gameId);
  Except
    on e: Exception do
    begin
      Console.Log('well, i ll move that in another place one day or another', C_RED);
      Exit;
    end;
  end;

  try
    game.AddPlayer(client);
  except
    on e: GameFullException do
    begin
      Console.Log(e.Message + ' should maybe tell to the user that the game is full?', C_RED);
      Exit;
    end;
  end;

  {
  // my player game info
  client.Send(
    #$48#$00 + #$00#$FF#$FF#$01 +
    client.Data.GameInformation
  );

  // Send my informations other player
  game.Send(
    #$48#$00 + #$01#$FF#$FF +
    client.Data.GameInformation
  );
  }

  // Lobby player informations
  playerLobby.Send(
    #$46#$00#$03#$01 +
    client.Data.LobbyInformations
  );

end;

procedure TgameServer.HandlePlayerLeaveGame(const client: TGameClient; const clientPacket: TClientPacket);
var
  playergame: TGame;
  playerLobby: TLobby;
begin
  Console.Log('TGameServer.HandlePlayerLeaveGame', C_BLUE);

  try
    playerLobby := m_lobbies.GetPlayerLobby(client);
  except
    on e: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  try
    playerGame := playerLobby.GetPlayerGame(client);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  playerGame.RemovePlayer(client);
  playerLobby.NullGame.AddPlayer(client);

  {
    // Game lobby info
    // if player count reach 0
    client.Send(
      #$47#$00#$01#$02#$FF#$FF +
      game.LobbyInformation
    );

    // if player count reach 0
    client.Send(
      #$47#$00#$01#$03#$FF#$FF +
      game.LobbyInformation
    );

  }

  // Lobby player informations
  {
  playerLobby.Send(
    #$46#$00#$03#$01 +
    client.Data.LobbyInformations
  );
  }

  client.Send(#$4C#$00#$FF#$FF);

end;

procedure TGameServer.HandlePlayerBuyItem(const client: TGameClient; const clientPacket: TClientPacket);
type
  TShopItemDesc = packed record
    un1: UInt32;
    IffId: TIffId;
    lifeTime: word;
    un2: array [0..1] of ansichar;
    qty: UInt32;
    un3: UInt32;
    un4: UInt32;
  end;
var
  rental: Byte;
  count: UInt16;
  I: integer;
  shopItem: TShopItemDesc;

  shopResult: TPacketData;
  successCount: uint16;
  randomId: Integer;
  test: TITEM_TYPE;
begin
  self.Log('TGameServer.HandlePlayerBuyItem', TLogType_not);

  shopResult := '';
  successCount := 0;
  {
    00000000  1D 00 00 01 00 FF FF FF  FF 13 40 14 08 00 00 FF    .....����.@....�
    00000010  FF 01 00 00 00 C4 09 00  00 00 00 00 00 00 00 00    �....�..........
    00000020  00                                                  .
  }
  clientPacket.ReadUInt8(rental);
  clientPacket.ReadUInt16(count);

  randomId := random(134775813);

  for I := 1 to count do
  begin
    clientPacket.Read(shopItem.un1, sizeof(TShopItemDesc));

    case TITEM_TYPE(shopItem.IffId.typ) of
      ITEM_TYPE_CHARACTER:
      begin
        Console.Log('ITEM_TYPE_CHARACTER');
      end;
      ITEM_TYPE_FASHION:
      begin
        Console.Log('ITEM_TYPE_FASHION');
        with client.Data.Items.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_CLUB:
      begin
        Console.Log('ITEM_TYPE_CLUB');
        with client.Data.Items.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_AZTEC:
      begin
        Console.Log('ITEM_TYPE_AZTEC');
        with client.Data.Items.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_ITEM1:
      begin
        Console.Log('ITEM_TYPE_ITEM1');
        with client.Data.Items.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_ITEM2:
      begin
        Console.Log('ITEM_TYPE_ITEM2');
        with client.Data.Items.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_CADDIE:
      begin
        Console.Log('ITEM_TYPE_CADDIE');
      end;
      ITEM_TYPE_CADDIE_ITEM:
      begin
        Console.Log('ITEM_TYPE_CADDIE_ITEM');
        with client.Data.Caddies.Add do
        begin
          SetIffId(shopItem.IffId.id);
          setId(Random(99999999));
        end;
      end;
      ITEM_TYPE_ITEM_SET:
      begin
        Console.Log('ITEM_TYPE_ITEM_SET');
      end;
      ITEM_TYPE_CADDIE_ITEM2:
      begin
        Console.Log('ITEM_TYPE_CADDIE_ITEM2');
      end;
      ITEM_TYPE_SKIN:
      begin
        Console.Log('ITEM_TYPE_SKIN');
      end;
      ITEM_TYPE_TITLE:
      begin
        Console.Log('ITEM_TYPE_TITLE');
      end;
      ITEM_TYPE_HAIR_COLOR1:
      begin
        Console.Log('ITEM_TYPE_HAIR_COLOR1');
      end;
      ITEM_TYPE_HAIR_COLOR2:
      begin
        Console.Log('ITEM_TYPE_HAIR_COLOR2');
      end;
      ITEM_TYPE_MASCOT:
      begin
        Console.Log('ITEM_TYPE_MASCOT');
      end;
      ITEM_TYPE_FURNITURE:
      begin
        Console.Log('ITEM_TYPE_FURNITURE');
      end;
      ITEM_TYPE_CARD_SET:
      begin
        Console.Log('ITEM_TYPE_CARD_SET');
      end;
      ITEM_TYPE_UNKNOW:
      begin
        Console.Log('ITEM_TYPE_UNKNOW');
      end
      else
      begin
        Console.Log(Format('Unknow item type %x', [shopItem.IffId.typ]));
      end;
    end;

    inc(successCount);
    shopResult := shopResult +
      self.Write(shopItem.IffId, 4) + // IffId
      self.Write(randomId, 4) + // Id
      #$00#$00#$00#$01 +
      #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
      #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00;
  end;

  // shop result
  client.Send(
    #$AA#$00 +
    self.Write(successCount, 2) +
    shopResult +
    self.Write(client.Data.data.playerInfo2.pangs, 8) +
    #$00#$00#$00#$00#$00#$00#$00#$00
  );

  // Pangs and cookies info
  client.Send(
    #$C8#$00 +
    self.Write(client.Data.data.playerInfo2.pangs, 8) +
    self.Write(client.Data.Cookies, 8)
  );

  // Pangs and cookies info
  client.Send(
    #$68#$00#$00#$00#$00#$00 +
    self.Write(client.Data.data.playerInfo2.pangs, 8) +
    self.Write(client.Data.Cookies, 8)
  );

end;

procedure TGameServer.HandlePlayerRequestIdentity(const client: TGameClient; const clientPacket: TClientPacket);
var
  mode: UInt32;
  playerName: AnsiString;
begin
  Console.Log('TGameServer.HandlePlayerRequestIdentity', C_BLUE);
  clientPacket.ReadUInt32(mode);
  clientPacket.ReadPStr(playerName);

  // TODO: should check if player can really do that
  client.Send(
    #$9A#$00 +
    Write(mode, 4)
  );

end;

procedure TGameServer.HandlePlayerRequestServerList(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.HandlePlayerRequestServerList', C_BLUE);
  // Should ask this to the sync server?
  client.Send(
    #$9F#$00 +
    #$00 // Number of servers
  );
end;

procedure TGameServer.HandlePlayerUpgrade(const client: TGameClient; const clientPacket: TClientPacket);
type
  TPacketHeader = packed record
    action: UInt8;
    upType: UInt8;
    itemId: UInt8;
  end;
var
  header: TPacketHeader;
  actionType: UInt8;
begin
  Console.Log('TGameServer.HandlePlayerNotice', C_BLUE);

  if not clientPacket.Read(header, SizeOf(TPacketHeader)) then
  begin
    Console.Log('Failed to read header', C_RED);
    Exit;
  end;

  actionType := 0;

  case header.action of
    0: // character upgrade
    begin  
      actionType := 1;
    end;
    1: // club upgrade
    begin 
      actionType := 1;
    end;
    2: // charcater downgrade
    begin
      actionType := 2;
    end;
    3: // club downgrade
    begin
      actionType := 3;
    end;
    else begin
      Console.Log('Unknow action');
    end;
  end;
  

  // upgrade result
  client.Send(
    #$A5#$00 +
    AnsiChar(actionType) + // upgrade type (upgrade|downgrade)
    AnsiChar(header.action) +
    AnsiChar(header.upType) +
    Write(header.itemId, 4) + // item id
    #$A4#$06#$00#$00#$00#$00#$00#$00
  );

  // Pangs and cookies info
  client.Send(
    #$C8#$00 +
    self.Write(client.Data.data.playerInfo2.pangs, 8) +
    self.Write(client.Data.Cookies, 8)
  );

end;

procedure TGameServer.HandlePlayerNotice(const client: TGameClient; const clientPacket: TClientPacket);
var
  notice: AnsiString;
begin
  Console.Log('TGameServer.HandlePlayerNotice', C_BLUE);
  // TODO: should check if the player can do that
  if clientPacket.ReadPStr(notice) then
  begin
    m_lobbies.Send(
      #$41#$00 +
      WritePStr(notice)
    );
  end;
end;

procedure TGameServer.HandlePlayerChangeEquipment(const client: TGameClient; const clientPacket: TClientPacket);
var
  packetData: TPacketData;
  itemType: UInt8;
  IffId: UInt32;
  characterData: TPlayerCharacterData;
begin
  self.Log('TGameServer.HandlePlayerChangeEquipment', TLogType_not);

  clientPacket.ReadUint8(itemType);

  case itemType of
    0: begin
      console.Log('should fix that', C_ORANGE);
      if clientPacket.Read(characterData, SizeOf(TPlayerCharacterData)) then
      begin
        client.Data.Data.equipedCharacter := characterData;
        client.Send(
          #$6B#$00 +
          #$04 + // no clue about it for now
          #$00 + // the above action?
          characterData.ToPacketData
        );
      end;
    end;
    2: begin
      Console.Log('look like equiped items');
    end
    else
    begin
      Console.Log(Format('Unknow item type %x', [itemType]), C_RED);
      clientPacket.Log;
    end;
  end;
end;

procedure TGameServer.HandlePlayerAction(const client: TGameClient; const clientPacket: TClientPacket);
var
  action: TPLAYER_ACTION;
  subAction: TPLAYER_ACTION_SUB;
  game: TGame;
  pos: TVector3;
  res: AnsiString;
  animationName: AnsiString;
  gamePlayer: TGameServerPlayer;
  test: TPlayerAction;
begin
  Console.Log('TGameServer.HandlePlayerAction', C_BLUE);

  Console.Log(Format('ConnectionId : %x', [client.Data.Data.playerInfo1.ConnectionId]));

  res := clientPacket.GetRemainingData;

  if not clientPacket.Read(action, 1) then
  begin
    Console.Log('Failed to read player action', C_RED);
    Exit;
  end;

  try
    game := m_lobbies.GetPlayerGame(client);
  except
    on e: Exception do
    begin
      Console.Log(e.Message, C_RED);
      Exit;
    end;
  end;

  gamePlayer := client.Data;

  case action of
    TPLAYER_ACTION.PLAYER_ACTION_APPEAR: begin

      console.log('Player appear');
      if not clientPacket.Read(gamePlayer.Action.pos.x, 12) then begin
        console.log('Failed to read player appear position', C_RED);
        Exit;
      end;

      with client.Data.Action do begin
        console.log(Format('pos : %f, %f, %f', [pos.x, pos.y, pos.z]));
      end;

    end;
    TPLAYER_ACTION.PLAYER_ACTION_SUB: begin

      console.log('player sub action');

      if not clientPacket.Read(subAction, 1) then begin
        console.log('Failed to read sub action', C_RED);
      end;

      client.Data.Action.lastAction := byte(subAction);

      case subAction of
        TPLAYER_ACTION_SUB.PLAYER_ACTION_SUB_STAND: begin
          console.log('stand');
        end;
        TPLAYER_ACTION_SUB.PLAYER_ACTION_SUB_SIT: begin
          console.log('sit');
        end;
        TPLAYER_ACTION_SUB.PLAYER_ACTION_SUB_SLEEP: begin
          console.log('sleep');
        end else begin
          console.log('Unknow sub action : ' + IntToHex(byte(subAction), 2));
          Exit;
        end;
      end;
    end;
    TPLAYER_ACTION.PLAYER_ACTION_MOVE: begin

        console.log('player move');

        if not clientPacket.Read(pos.x, 12) then begin
          console.log('Failed to read player moved position', C_RED);
          Exit;
        end;

        client.Data.Action.pos.x := client.Data.Action.pos.x + pos.x;
        client.Data.Action.pos.y := client.Data.Action.pos.y + pos.y;
        client.Data.Action.pos.z := pos.z;

        with client.Data.Action do begin
          console.log(Format('pos : %f, %f, %f', [pos.x, pos.y, pos.z]));
        end;
    end;
    TPLAYER_ACTION.PLAYER_ACTION_ANIMATION: begin
      console.log('play animation');
      clientPacket.ReadPStr(animationName);
      console.log('Animation : ' + animationName);
    end else begin
      console.log('Unknow action ' + inttohex(byte(action), 2));
      Exit;
    end;
  end;

  SendToGame(client,
    #$C4#$00 +
    Write(client.Data.Data.playerInfo1.ConnectionId, 4) +
    res
  );
end;

procedure TGameServer.HandlePlayerJoinMultiplayerGamesList(const client: TGameClient; const clientPacket: TClientPacket);
var
  playerLobby: TLobby;
begin
  Console.Log('TGameServer.HandlePlayerJoinMultiplayerGamesList', C_BLUE);

  try
    playerLobby := m_lobbies.GetPlayerLobby(client);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  playerLobby.JoinMultiplayerGamesList(client);
end;

procedure TGameServer.HandlePlayerLeaveMultiplayerGamesList(const client: TGameClient; const clientPacket: TClientPacket);
var
  playerLobby: TLobby;
begin
  Console.Log('TGameServer.HandlePlayerLeaveMultiplayerGamesList', C_BLUE);

  try
    playerLobby := m_lobbies.GetPlayerLobby(client);
  except
    on E: Exception do
    begin
      Console.Log(E.Message, C_RED);
      Exit;
    end;
  end;

  playerLobby.LeaveMultiplayerGamesList(client);
end;

procedure TGameServer.HandlePlayerOpenRareShop(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.HandlePlayerOpenRareShop', C_BLUE);
  client.Send(#$0B#$01#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$00#$00#$00#$00);
end;

procedure TGameServer.handlePlayerRequestMessengerList(const client: TGameClient; const clientPacket: TClientPacket);
var
  packet: TClientPacket;
begin
  Console.Log('TGameServer.handlePlayerRequestMessengerList', C_BLUE);

  packet := TClientPacket.Create;
  
  packet.WriteStr(
    #$FC#$00 + 
    #$01 + 
    #$4D#$53#$4E#$5F#$31#$00#$69#$00#$00#$50#$40#$32#$00 +
    #$00#$00#$00#$00#$60#$00#$00#$00#$50#$40#$32#$08#$50#$40#$32#$78 +
    #$01#$E7#$00#$00#$00#$00#$00#$00#$60#$00#$00#$F7#$04#$00#$00#$88 +
    #$13#$00#$00#$F9#$00#$00#$00
  );
  
  packet.WriteStr('127.0.0.1', 15, #$00);

  packet.WriteStr(
    #$00#$03#$04#$00#$D0#$1E#$00#$00#$00#$10#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00
  );

  client.Send(packet);
  
  packet.free;
end;

procedure TGameServer.HandlePlayerGMCommaand(const client: TGameClient; const clientPacket: TClientPacket);
var
  command: UInt16;
  tmpUInt32: UInt32;
  tmpUInt16: UInt16;
  tmpUInt8: UInt8;
  game: TGame;
begin
  Console.Log('TGameServer.HandlePlayerGMCommaand', C_BLUE);

  try
    game := m_lobbies.GetPlayerGame(client);
  except
    Console.Log('Failed to get player game');
    Exit;
  end;

  if not clientPacket.ReadUInt16(command) then
  begin
    Console.Log(Format('Unknow Command %d', [command]), C_RED);
    Exit;
  end;

  case command of
    3: begin // visible (on|off)

    end;
    4: begin // whisper (on|off)

    end;
    5: begin // channel (on|off)

    end;
    $E: begin // wind (speed - dir)

    end;
    $A: begin // kick
      if (clientPacket.ReadUInt32(tmpUInt32)) then
      begin

      end;
    end;
    $F: begin // weather (fine|rain|snow|cloud)
      console.Log('weather');
      if (clientPacket.ReadUInt8(tmpUInt8)) then
      begin
        game.Send(#$9E#$00 + AnsiChar(tmpUInt8) + #$00#$00);
      end;
    end;
  end;

end;

procedure TGameServer.HandlePlayerUnknow00EB(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.HandlePlayerUnknow0140', C_BLUE);
  // Should send that to all players
  client.Send(
    #$96#$01 +
    #$4E#$01#$00#$00 + #$00#$00#$80#$3F + #$00#$00#$80#$3F +
    #$00#$00#$80#$3F + #$00#$00#$80#$3F + #$00#$00#$80#$3F
  );
end;

procedure TGameServer.HandlePlayerOpenScratchyCard(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.HandlePlayerOpenScratchyCard', C_BLUE);
  client.Send(#$EB#$01#$00#$00#$00#$00#$00);
end;

procedure TGameServer.HandlePlayerSetAssistMode(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.log('TGameServer.HandlePlayerSetAssistMode');

  client.Send(
    #$16#$02 +
    #$D9#$C2#$53#$56 + // seem to increase
    #$01#$00#$00#$00#$02#$16#$00#$E0#$1B#$12 +
    #$49#$76#$06#$00#$00#$00#$00 +
    #$01#$00#$00#$00 +
    #$02#$00#$00#$00 +
    #$01#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00
  );

  client.Send(
    #$6A#$02 + #$00#$00#$00#$00
  );
end;

procedure TGameServer.HandlePlayerUnknow0140(const client: TGameClient; const clientPacket: TClientPacket);
begin
  self.Log('TGameServer.HandlePlayerUnknow0140', TLogType_not);
  client.Send(#$0E#$02#$00#$00#$00#$00#$00#$00#$00#$00);
end;

procedure TGameServer.HandlePlayerRequestAchievements(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.HandlePlayerRequestInfo', C_BLUE);

  {
    supposed to send all achievement data here
    packet $022D (check the logs)
  }

  client.Send(#$2C#$02 + #$00#$00#$00#$00);
end;

procedure TGameServer.PlayerRequestDailyReward(const client: TGameClient; const clientPacket: TClientPacket);
begin
  Console.Log('TGameServer.PlayerRequestDailyReward', C_BLUE);
  client.Send(
    #$48#$02 +
    #$00#$00#$00#$00#$01#$08#$02#$00#$1A#$01#$00#$00#$00 +
    #$05#$00#$00#$18 + // item id
    #$03#$00#$00#$00 + // item count
    #$1E#$00#$00#$00 // days logged
  );
end;

procedure TGameServer.HandlePlayerRequestInfo(const client: TGameClient; const clientPacket: TClientPacket);
var
  res: TClientPacket;
  playerId: UInt32;
  un1: UInt8;
begin
  Console.Log('TGameServer.HandlePlayerRequestInfo', C_BLUE);

  if not clientPacket.ReadUInt32(playerId) then
  begin
    Exit;
  end;

  if not clientPacket.ReadUInt8(un1) then
  begin
    Exit;
  end;

  // Always send current player for now
  res := TClientPacket.Create;

  // Player infos
  res.WriteStr(#$57#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.Write(client.Data.Data.playerInfo1, SizeOf(TPlayerInfo1));
  res.WriteUInt32(0); // have some more data at the end
  client.Send(res);
  res.Clear;

  // Equiped character
  res.WriteStr(#$5E#$01);
  res.WriteUInt32(playerId);
  res.Write(client.Data.Data.equipedCharacter, SizeOf(TPlayerCharacterData));
  client.Send(res);
  res.Clear;

  // Equiped character
  res.WriteStr(#$56#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.Write(client.Data.Data.witems, SizeOf(TPlayerEquipedItems));
  client.Send(res);
  res.Clear;

  // Player info 2
  res.WriteStr(#$58#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.Write(client.Data.Data.playerInfo2, SizeOf(TPlayerInfo2));
  client.Send(res);
  res.Clear;

  // Guild informations
  res.WriteStr(#$5D#$01);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$67#$75#$69#$6C#$64#$6D#$61#$72#$6B +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$FF#$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$87#$E7#$00#$20#$0E +
    #$9E#$09#$50#$9C#$B9#$01#$64#$F6#$9F#$0E#$A8
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$5C#$01 + #$33);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00#$00#$00#$00#$00#$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$5C#$01 + #$34);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00#$00#$00#$00#$00#$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$5B#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$5A#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$59#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
    #$00#$00#$00#$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$5C#$01);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00#$00#$00#$00#$00#$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$57#$02);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  res.WriteStr(
    #$00#$00
  );
  client.Send(res);
  res.Clear;

  // Unknow
  res.WriteStr(#$89#$00 + #$01#$00#$00#$00);
  res.WriteUInt8(un1);
  res.WriteUInt32(playerId);
  client.Send(res);
  res.Clear;

  res.Free;
end;

procedure TGameServer.HandleLobbyRequests(const lobby: TLobby; const packetId: TCGPID; const client: TGameClient; const clientPacket: TClientPacket);
var
  playerGame: TGame;
begin
  case packetId of
    CGPID_PLAYER_MESSAGE:
    begin
      self.HandlePlayerSendMessage(client, clientPacket);
    end;
    CGPID_PLAYER_CREATE_GAME:
    begin
      self.HandlePlayerCreateGame(client, clientPacket);
    end;
    CGPID_PLAYER_JOIN_GAME:
    begin
      self.HandlePlayerJoinGame(client, clientPacket);
    end;
    CGPID_PLAYER_LEAVE_GAME:
    begin
      self.HandlePlayerLeaveGame(client, clientPacket);
    end;
    CGPID_PLAYER_BUY_ITEM:
    begin
      self.HandlePlayerBuyItem(client, clientPacket);
    end;
    CGPID_PLAYER_CHANGE_EQUIP:
    begin
      self.HandlePlayerChangeEquipment(client, clientPacket);
    end;
    CGPID_PLAYER_REQUEST_IDENTITY:
    begin
      self.HandlePlayerRequestIdentity(client, clientPacket);
    end;
    CGPID_PLAYER_REQQUEST_SERVERS_LIST:
    begin
      self.HandlePlayerRequestServerList(client, clientPacket);
    end;
    CGPID_PLAYER_UPGRADE:
    begin
      self.HandlePlayerUpgrade(client, clientPacket);
    end;
    CGPID_PLAYER_NOTICE:
    begin
      self.HandlePlayerNotice(client, clientPacket);
    end;
    CGPID_PLAYER_ACTION:
    begin
      self.HandlePlayerAction(client, clientPacket);
    end;
    CGPID_PLAYER_JOIN_MULTIPLAYER_GAME_LIST:
    begin
      self.HandlePlayerJoinMultiplayerGamesList(client, clientPacket);
    end;
    CGPID_PLAYER_LEAVE_MULTIPLAYER_GAME_LIST:
    begin
      self.HandlePlayerLeaveMultiplayerGamesList(client, clientPacket);
    end;
    CGPID_PLAYER_REQUEST_MESSENGER_LIST:
    begin
      self.handlePlayerRequestMessengerList(client, clientPacket);
    end;
    CGPID_PLAYER_GM_COMMAND:
    begin
      self.HandlePlayerGMCommaand(client, clientPacket);
    end;
    CGPID_PLAYER_OPEN_RARE_SHOP:
    begin
      self.HandlePlayerOpenRareShop(client, clientPacket);
    end;
    CGPID_PLAYER_UN_00EB:
    begin
      self.HandlePlayerUnknow00EB(client, clientPacket);
    end;
    CGPID_PLAYER_OPEN_SCRATCHY_CARD:
    begin
      self.HandlePlayerOpenScratchyCard(client, clientPacket);
    end;
    CGPID_PLAYER_UN_0140:
    begin
      self.HandlePlayerUnknow0140(client, clientPacket);
    end;
    CGPID_PLAYER_REQUEST_INFO:
    begin
      self.HandlePlayerRequestInfo(client, clientPacket);
    end;
    CGPID_PLAYER_REQUEST_ACHIEVEMENTS:
    begin
      self.HandlePlayerRequestAchievements(client, clientPacket);
    end;
    CGPID_PLAYER_REQUEST_DAILY_REWARD:
    begin
      self.PlayerRequestDailyReward(client, clientPacket);
    end;
    else begin
      try
        playerGame := lobby.GetPlayerGame(client);
        self.HandleGameRequests(playerGame, packetId, client, clientPacket);
      except
        on e: Exception do
        begin
          Console.Log(e.Message, C_RED);
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TGameServer.HandleGameRequests(const game: TGame; const packetId: TCGPID; const client: TGameClient; const clientPacket: TClientPacket);
begin
  case packetId of
    CGPID_PLAYER_CHANGE_GAME_SETTINGS:
    begin
      game.HandlePlayerChangeGameSettings(client, clientPacket);
    end;
    CGPID_PLAYER_SET_ASSIST_MODE:
    begin
      self.HandlePlayerSetAssistMode(client, clientPacket);
    end;
    CGPID_PLAYER_READY:
    begin
      game.HandlePlayerReady(client, clientPacket);
    end;
    CGPID_PLAYER_START_GAME:
    begin
      game.HandlePlayerStartGame(client, clientPacket);
    end;
    CGPID_PLAYER_LOADING_INFO:
    begin
      game.HandlePlayerLoadingInfo(client, clientPacket);
    end;
    CGPID_PLAYER_LOAD_OK:
    begin
      game.HandlePlayerLoadOk(client, clientPacket);
    end;
    CGPID_PLAYER_HOLE_INFORMATIONS:
    begin
      game.HandlePlayerHoleInformations(client, clientPacket);
    end;
    CGPID_PLAYER_1ST_SHOT_READY:
    begin
      game.HandlePlayer1stShotReady(client, clientPacket);
    end;
    CGPID_PLAYER_ACTION_SHOT:
    begin
      game.HandlePlayerActionShot(client, clientPacket);
    end;
    CGPID_PLAYER_ACTION_ROTATE:
    begin
      game.HandlePlayerActionRotate(client, clientPacket);
    end;
    CGPID_PLAYER_ACTION_HIT:
    begin
      game.HandlePlayerActionHit(client, clientPacket);
    end;
    CGPID_PLAYER_ACTION_CHANGE_CLUB:
    begin
      game.HandlePlayerActionChangeClub(client, clientPacket);
    end;
    CGPID_PLAYER_SHOTDATA:
    begin
      game.HandlePlayerShotData(client, clientPacket);
    end;
    CGPID_PLAYER_SHOT_SYNC:
    begin
      game.HandlePlayerShotSync(client, clientPacket);
    end;
    CGPID_PLAYER_HOLE_COMPLETE:
    begin
      game.HandlerPlayerHoleComplete(client, clientPacket);
    end
    else begin
      self.Log(Format('Unknow packet Id %x', [Word(packetID)]), TLogType_err);
    end;
  end;
end;

procedure TGameServer.OnReceiveClientData(const client: TGameClient; const clientPacket: TClientPacket);
var
  player: TGameServerPlayer;
  packetId: TCGPID;
  playerLobby: TLobby;
begin
  self.Log('TGameServer.OnReceiveClientData', TLogType_not);
  clientPacket.Log;

  player := client.Data;
  if (clientPacket.Read(packetID, 2)) then
  begin
    case packetID of
      CGPID_PLAYER_LOGIN:
      begin
        self.HandlePlayerLogin(client, clientPacket);
      end;
      CGPID_PLAYER_JOIN_LOBBY:
      begin
        self.HandlePlayerJoinLobby(client, clientPacket);
      end;
      else
      begin
        try
          playerLobby := m_lobbies.GetPlayerLobby(client);
          self.HandleLobbyRequests(playerLobby, packetId, client, clientPacket);
        except
          on e: Exception do
          begin
            Console.Log(e.Message, C_RED);
            Exit;
          end;
        end;
      end;
    end;
  end;
end;

// TODO: move that to parent class
procedure TGameServer.PlayerSync(const clientPacket: TClientPacket; const client: TGameClient);
var
  actionId: TSGPID;
begin
  self.Log('TGameServer.PlayerSync', TLogType_not);
  client.Send(clientPacket.GetRemainingData);
end;

procedure TGameServer.ServerPlayerAction(const clientPacket: TClientPacket; const client: TGameClient);
var
  actionId: TSSAPID;
  buffer: AnsiString;
  d: AnsiString;
begin
  self.Log('TGameServer.PlayerSync', TLogType_not);
  if clientPacket.Read(actionId, 2) then
  begin
    case actionId of
      SSAPID_SEND_LOBBIES_LIST:
      begin
        client.Send(LobbiesList);
      end;
      SSAPID_PLAYER_MAIN_SAVE:
      begin
        buffer := clientPacket.GetRemainingData;

        client.Data.Data.Load(buffer);

        client.Data.Data.playerInfo1.ConnectionId := client.ID;
        client.Send(
          WriteHeader(SGPID_PLAYER_MAIN_DATA) +
          #$00 +
          WritePStr('824.00') +
          WritePStr(ExtractFilename(ParamStr(0))) +
          client.Data.Data.ToPacketData
        );
      end;
      SSAPID_PLAYER_CHARACTERS:
      begin
        Console.Log('Characters');
        client.Data.Characters.Load(clientPacket.GetRemainingData);
        client.Send(
          WriteHeader(SGPID_PLAYER_CHARACTERS_DATA) +
          client.Data.Characters.ToPacketData
        );
      end;
      SSAPID_PLAYER_ITEMS:
      begin
        Console.Log('Items');
        client.Data.Items.Load(clientPacket.GetRemainingData);
        Console.WriteDump(client.Data.items.ToPacketData);
        client.Send(
          WriteHeader(SGPID_PLAYER_ITEMS_DATA) +
          client.Data.items.ToPacketData
        );
      end;
      SSAPID_PLAYER_CADDIES:
      begin
        Console.Log('Caddies');
        client.Data.Caddies.Load(clientPacket.GetRemainingData);
        Console.WriteDump(client.Data.Caddies.ToPacketData);
        client.Send(
          WriteHeader(SGPID_PLAYER_CADDIES_DATA) +
          client.Data.Caddies.ToPacketData
        );

        // mascot list
        client.Send(#$E1#$00#$00);

      end;
      else
      begin
        self.Log(Format('Unknow action Id %x', [Word(actionId)]), TLogType_err);
      end;
    end;
  end;

end;

procedure TGameServer.OnDestroyClient(const client: TGameClient);
begin
  client.Data.Free;
end;

procedure TGameServer.OnReceiveSyncData(const clientPacket: TClientPacket);
var
  packetId: TSSPID;
  playerUID: TPlayerUID;
  client: TGameClient;
begin
  self.Log('TLoginServer.OnReceiveSyncData', TLogType_not);
  if (clientPacket.Read(packetID, 2)) then
  begin

    clientPacket.ReadUInt32(playerUID.id);
    clientPacket.ReadPStr(playerUID.login);

    client := self.GetClientByUID(playerUID);
    if client = nil then
    begin
      Console.Log('something went wrong client not found', C_RED);
      Exit;
    end;

    if client.UID.id = 0 then
    begin
      client.UID.id := playerUID.id;
    end;
    console.Log(Format('player UID : %s/%d', [playerUID.login, playerUID.id]));

    case packetId of
      SSPID_PLAYER_SYNC:
      begin
        self.PlayerSync(clientPacket, client);
      end;
      SSPID_PLAYER_ACTION:
      begin
        self.ServerPlayerAction(clientPacket, client);
      end;
      else
      begin
        self.Log(Format('Unknow packet Id %x', [Word(packetID)]), TLogType_err);
      end;
    end;
  end;
end;

procedure TGameServer.SendToGame(const client: TGameClient; data: AnsiString);
var
  game: TGame;
begin
  try
    game := m_lobbies.GetPlayerGame(client);
  except
    on e: Exception do
    begin
      Console.Log(e.Message, C_RED);
      Exit;
    end;
  end;
  game.Send(data);
end;

procedure TGameServer.SendToGame(const client: TGameClient; data: TPangyaBuffer);
var
  game: TGame;
begin
  try
    game := m_lobbies.GetPlayerGame(client);
  except
    on e: Exception do
    begin
      Console.Log(e.Message, C_RED);
      Exit;
    end;
  end;
  game.Send(data);
end;

procedure TGameServer.SendToLobby(const client: TGameClient; data: AnsiString);
var
  lobby: TLobby;
begin
  try
    lobby := m_lobbies.GetPlayerLobby(client);
  except
    on e: Exception do
    begin
      Console.Log(e.Message, C_RED);
      Exit;
    end;
  end;
  lobby.Send(data);
end;

procedure TGameServer.SendToLobby(const client: TGameClient; data: TPangyaBuffer);
var
  lobby: TLobby;
begin
  try
    lobby := m_lobbies.GetPlayerLobby(client);
  except
    on e: Exception do
    begin
      Console.Log(e.Message, C_RED);
      Exit;
    end;
  end;
  lobby.Send(data);
end;

end.
