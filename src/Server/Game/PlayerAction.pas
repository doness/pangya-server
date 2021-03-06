{*******************************************************}
{                                                       }
{       Pangya Server                                   }
{                                                       }
{       Copyright (C) 2015 Shad'o Soft tm               }
{                                                       }
{*******************************************************}

unit PlayerAction;

interface

uses Types.Vector3;

type

  PPlayerAction = ^TPlayerAction;
  TPlayerAction = packed record
    lastAction: cardinal;
    pos: TVector3;
    procedure clear;
    function toAnsiString: ansistring;
  end;

implementation

procedure TPlayerAction.clear;
begin
  FillChar(self.lastAction, SizeOf(TPlayerAction), 0);
end;

function TPlayerAction.toAnsiString: ansistring;
begin
  setLength(result, sizeof(TPlayerAction));
  move(lastAction, result[1], sizeof(TPlayerAction));
end;

end.
