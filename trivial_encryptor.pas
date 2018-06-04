unit trivial_encryptor;

{$mode objfpc}{$H+}

interface

type

  { TRandom32 }

  TRandom32 = class
    m_seed:cardinal;
  public
    procedure seed(s:cardinal);
    function random(range:cardinal):cardinal;
  end;

  { TTrivialEncryptor }

  TTrivialEncryptor = class
    m_alphabet:array[0..255] of byte;
    m_alphabet_back:array[0..255] of byte;

    m_table_iterations:cardinal;
  	m_table_seed:cardinal;
  	m_encrypt_seed:cardinal;
  public
    procedure Init(tbl_iter:cardinal; tbl_seed:cardinal; enc_seed:cardinal);
    procedure decode(source:pointer; source_size:cardinal; destination:pointer);

    procedure Init_RU();
    procedure Init_WW();
  end;

implementation

{ TTrivialEncryptor }

procedure TTrivialEncryptor.Init(tbl_iter:cardinal; tbl_seed:cardinal; enc_seed:cardinal);
var
  i, j, k, t:cardinal;
  temp:TRandom32;
begin
  m_table_iterations:=tbl_iter;
  m_table_seed:=tbl_seed;
  m_encrypt_seed:=enc_seed;

  for i:=0 to length(m_alphabet)-1 do begin
    m_alphabet[i]:=i;
  end;

  temp:=TRandom32.Create;
  temp.seed(m_table_seed);

  for i:=0 to m_table_iterations-1 do begin
    j:=temp.random(length(m_alphabet));
    k:=temp.random(length(m_alphabet));

		while (j = k) do k := temp.random(length(m_alphabet));

    t:=m_alphabet[j];
    m_alphabet[j]:=m_alphabet[k];
    m_alphabet[k]:=t;
  end;

	for i:=0 to length(m_alphabet)-1 do begin
		m_alphabet_back[m_alphabet[i]] := i;
  end;

end;

procedure TTrivialEncryptor.decode(source: pointer; source_size: cardinal; destination: pointer);
var
  I, E, J:pByte;
  temp:TRandom32;
  id:byte;
begin
  temp:=TRandom32.Create();
	temp.seed(m_encrypt_seed);
  I:=source;
  E:=@I[source_size];
  J:=destination;

  while I<>E do begin
    id:=I^ xor byte(temp.random(length(m_alphabet)) and $FF);
    J^:=m_alphabet_back[id];
    I:=@I[1];
    J:=@J[1];
  end;
end;

procedure TTrivialEncryptor.Init_RU();
begin
  Init(2048, 20091958, 20031955);
end;

procedure TTrivialEncryptor.Init_WW();
begin
  Init(1024, 6011979, 24031979);
end;

{ TRandom32 }

procedure TRandom32.seed(s: cardinal);
begin
  m_seed:=s;
end;

function TRandom32.random(range:cardinal): cardinal;
begin
	m_seed:=cardinal(qword($08088405*m_seed) + 1);
	result:=(cardinal(qword(m_seed)*qword(range) shr 32));
end;

end.

