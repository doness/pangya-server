{*******************************************************}
{                                                       }
{       Pangya Server                                   }
{                                                       }
{       Copyright (C) 2015 Shad'o Soft tm               }
{                                                       }
{*******************************************************}

unit SyncUser;

interface

type

  TSYNC_CLIENT_TYPE = (
    SYNC_CLIENT_TYPE_UNKNOW = 0,
    SYNC_CLIENT_TYPE_LOGIN = 1,
    SYNC_CLIENT_TYPE_GAME = 2
  );

  TSyncUser = class
    private
      var m_type: TSYNC_CLIENT_TYPE;
      var m_registred: Boolean;
    public
      constructor Create;
      destructor Destroy; override;
      property ClientType: TSYNC_CLIENT_TYPE read m_type write m_type;
  end;

implementation

constructor TSyncUser.Create;
begin
  inherited;
  self.m_type := TSYNC_CLIENT_TYPE.SYNC_CLIENT_TYPE_UNKNOW;
  m_registred := false;
end;

destructor TSyncUser.Destroy;
begin
  inherited;
end;

end.
