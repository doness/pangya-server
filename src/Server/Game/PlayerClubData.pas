{*******************************************************}
{                                                       }
{       Pangya Server                                   }
{                                                       }
{       Copyright (C) 2015 Shad'o Soft tm               }
{                                                       }
{*******************************************************}

unit PlayerClubData;

interface

uses ClubStats;

type

  TPlayerClubData = packed record
    Id: UInt32;
    IffId: UInt32;
    Un1: array [0..$9] of ansichar;
    Stats: TClubStats;
    function ToStr: AnsiString;
  end;

implementation

function TPlayerClubData.ToStr: AnsiString;
begin
  setLength(result, sizeof(TPlayerClubData));
  move(self, result[1], sizeof(TPlayerClubData));
end;

end.
