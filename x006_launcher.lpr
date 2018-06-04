program x006_launcher;

uses INIFiles, windows, sysutils, trivial_encryptor;

function GetNextParam(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=1 to length(data) do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=leftstr(data, p-1);
    data:=rightstr(data, length(data)-p);
    result:=true;
  end else result:=false;
end;

function ValidateArchive(path:string; temp_stuff:TTrivialEncryptor):boolean;
var
  f:THandle;
  chunkid, chunksz:cardinal;
  readcnt:cardinal;
  arr_in, arr_out:array of byte;
const
  CHUNK_ID:cardinal = $80000001;
  INVALID_SET_FILE_POINTER:cardinal = $FFFFFFFF;
begin
  result:=false;
  readcnt:=0;
  chunkid:=0;
  chunksz:=0;
  f:=INVALID_HANDLE_VALUE;
  try
    f:=CreateFile(PAnsiChar(path), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if f <> INVALID_HANDLE_VALUE then begin
      //Найдем чанк с пошифрованной таблицей
      chunkid:=0;
      while true do begin
        if not ReadFile(f, chunkid, sizeof(chunkid), readcnt, nil) or (readcnt<>sizeof(chunkid)) then exit;
        if not ReadFile(f, chunksz, sizeof(chunksz), readcnt, nil) or (readcnt<>sizeof(chunksz)) then exit;
        if chunkid = CHUNK_ID then break;
        if SetFilePointer(f, chunksz, nil, FILE_CURRENT) = INVALID_SET_FILE_POINTER then exit;
      end;

      //Вычитаем его
      SetLength(arr_in, chunksz);
      SetLength(arr_out, chunksz);
      if not ReadFile(f, arr_in[0], chunksz, readcnt, nil) or (readcnt<>chunksz) then exit;
      temp_stuff.decode(@arr_in[0], chunksz, @arr_out[0]);

      //Первые 4 байта - размер разжатых данных. Так как разжимать данные мы не хотим (да и не факт, что нормально раскомпрессится), просто убедимся, что он достаточно мал.
      result:=(arr_out[3] = 0);
    end;
  finally
    if f<>INVALID_HANDLE_VALUE then begin
      CloseHandle(f);
    end;
    SetLength(arr_in, 0);
    SetLength(arr_out, 0);
  end;
end;

function ValidateGameArchives(path:string; temp_stuff:TTrivialEncryptor):boolean;
var
  SR: TSearchRec;
begin
  result:=false;

  if FindFirst(path+'gamedata.db*', faAnyFile, SR) = 0 then begin
    result:=true;
    repeat
      if not ValidateArchive(path+sr.Name, temp_stuff) then begin
        result:=false;
        break;
      end;
    until FindNext(SR) <> 0;
  end;
end;

var
  fsltx:TextFile;
  tmpstr, gameroot:string;
  errmsg:string;
  engine_name, locale_name:string;
  cmdline:string;
  i:cardinal;

  temp_stuff:TTrivialEncryptor;

  pi:TPROCESSINFORMATION;
  si:TSTARTUPINFO;
const
  root_param:string = '$parent_game_root$';
  target_engine_name:string = 'bin\xr_3DA.exe';
  target_locale_name:string = 'mods\localization.xdb';

{$R *.res}

begin
  temp_stuff:=TTrivialEncryptor.Create();
  try
    //откроем fsgame.ltx и вычитаем оттуда расположение оригинальной игры
    errmsg:='Opening fsgame.ltx failed';
    assignfile(fsltx, 'fsgame.ltx');
    reset(fsltx);

    errmsg:='Cannot find '+root_param+' dir in fsgame.ltx';
    while not eof(fsltx) do begin
      readln(fsltx, gameroot);
      gameroot:=trim(gameroot);
      if leftstr(gameroot, length(root_param)) = root_param then begin
        while GetNextParam(gameroot, tmpstr, '|') do begin end;
        if gameroot<>'' then begin
          errmsg:='';
        end;
        break;
      end;
    end;
    CloseFile(fsltx);
    if length(errmsg)>0 then exit;

    //Посмотрим на архив gamedata.db0, реально ли от русской он версии?
    errmsg:='Cannot validate archive';
    temp_stuff.Init_RU();
    if ValidateGameArchives(gameroot, temp_stuff) then begin
      errmsg:='';
      engine_name:='bin\xr_3da.rus';
      locale_name:='mods\localization.rus';
    end else begin
      temp_stuff.Init_WW();
      if ValidateGameArchives(gameroot, temp_stuff) then begin
        errmsg:='';
        engine_name:='bin\xr_3da.eng';
        locale_name:='mods\localization.eng';
      end else begin
        errmsg:='Strange game installation - can''t determine archives'' format';
      end;
    end;

    if length(errmsg) = 0 then begin
      if not CopyFile(PAnsiChar(locale_name), PAnsiChar(target_locale_name), false) then begin
        errmsg:='Cannot copy localization '+locale_name;
      end;

      if not CopyFile(PAnsiChar(engine_name), PAnsiChar(target_engine_name), false) then begin
        errmsg:='Cannot copy engine '+engine_name;
      end;
    end;

    if length(errmsg) = 0 then begin
      ZeroMemory(@si, sizeof(si));
      ZeroMemory(@pi, sizeof(pi));
      cmdline:=target_engine_name+' ';
      i:=1;
      while length(ParamStr(i)) > 0 do begin
        cmdline:=cmdline+ParamStr(i)+' ';
        i:=i+1;
      end;

      if not CreateProcess(PAnsiChar(target_engine_name), PAnsiChar(cmdline), nil, nil, false, 0, nil, PAnsiChar(GetCurrentDir()), si, pi) then begin
        errmsg:='Cannot start engine';
      end else begin
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
      end;
    end;

  finally
    if errmsg<>'' then begin
      MessageBox(0, PAnsiChar(errmsg), 'ERROR', MB_OK or MB_ICONERROR);
    end;
    temp_stuff.Free();
  end;
end.

