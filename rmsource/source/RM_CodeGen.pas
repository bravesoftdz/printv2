{***************************************************************}
{                                         ����������������������}
{              Report Machine            ���������������������� }
{                                       ����������������������  }
{             Script code gen          ����������������������   }
{             �¼���������������dejoy�����ṩ������������������ }
{                                         ����������������������}
{           ����: dejoy(qq:23487189)                            }
{***************************************************************}

unit RM_CodeGen;

{$I RM.INC}

interface

uses
  Windows, Messages, Controls, Classes, Registry,
  SysUtils
{$IFDEF COMPILER6_UP}, StrUtils, Variants{$ENDIF}
{$IFDEF USE_INTERNAL_JVCL}
  , rm_JvInterpreter, rm_JvInterpreterFm
{$ELSE}
  , JvInterpreter, JvInterpreterFm
{$ENDIF}
  ;

const
  Tag_Initprocedure = 'InitializeComponent';

type

  TGetStringsEvent = procedure(const AList: TStrings) of object;

{TRMCodeGenEngine}
  TRMCodeGenEngine = class(TPersistent)
  private
    FScriptInterpreter: TJvInterpreterProgram;
    FOnGetScript: TGetStringsEvent;
    FOnScriptChanged: TNotifyEvent;

    function GetScriptInterpreter: TJvInterpreterProgram;
    function GetScript: TStrings;
    procedure SetScript(const Value: TStrings);

    function GetScriptText: string;
    procedure SetScriptText(const Value: string);
  protected
    ScriptCompiled: Boolean;
    procedure DoGetScript;
    procedure DoScriptChanged;
  public
    procedure Modified;
    function CompileScript: boolean; virtual;
    function GetFunDesc(ASrcFunName: string): TJvInterpreterFunctionDesc;

    {�����������}
    {��ȡ�����¼��ĳ��������}

    {����¼�����������(����)
     aFunctionName    ��������,��'Memo1_OnBeforePrint' ;
     aFunctionDefine  �����ĺ���������:
     'procedure Memo1_OnBeforePrint(Sender: TObject);';
     aCode            �������,���ð���Begin ..and;
     ����ֵΪ��������λ��.

     ʾ��:
     AddFunctionCode('Memo1_OnBeforePrint',
       'procedure Memo1_OnBeforePrint(Sender: TObject);',
       'Showmessage('ok');');
    }
    function AddFunctionCode(aFunctionName, aFunctionDefine: string;
      aCode: TStringList; aAppendCodeIfExist: Boolean = False): integer; overload;
    function AddFunctionCode(aFunctionName, aFunctionDefine: string;
      aCode: string; aAppendCodeIfExist: Boolean = False): integer; overload;

    procedure GetFunctionCode(aFunctionName: string; aCode: TStringList); overload;
    function GetFunctionCode(aFunctionName: string): string; overload;

    function FunctionExists(const aFunctionName: string): Boolean;
    function RenameFunction(const CurName, NewName: string): Boolean;
    function DeleteFunction(const aFunctionName: string): Boolean;

    function GetFunctionPos(const aFunctionName: string): integer;
    {���غ������뿪ʼ��λ��(Begin֮��)    }
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property OnScriptChanged: TNotifyEvent read FOnScriptChanged write FOnScriptChanged;
    property OnGetScript: TGetStringsEvent read FOnGetScript write FOnGetScript;
    property Script: TStrings read GetScript write SetScript;
    property ScriptText: string read GetScriptText write SetScriptText;
    property ScriptEngine: TJvInterpreterProgram read GetScriptInterpreter;

  published

  end;

implementation

uses
{$IFDEF USE_INTERNAL_JVCL}
  rm_JvJCLUtils, rm_JclStrings;
{$ELSE}
  JvJCLUtils, JclStrings;
{$ENDIF USE_INTERNAL_JVCL}

type
  THackEngine = class(TJvInterpreterFm);
  THackJvInterpreterProgram = class(TJvInterpreterProgram);
  THackJvInterpreterAdapter = class(TJvInterpreterAdapter);

{ TRMCodeGenEngine }

function TRMCodeGenEngine.AddFunctionCode(aFunctionName, aFunctionDefine,
  aCode: string; aAppendCodeIfExist: Boolean): integer;
var
  ilist: TStringList;
begin
  ilist := TStringList.Create;
  try
    ilist.Text := aCode;
    Result := AddFunctionCode(aFunctionName, aFunctionDefine, ilist, aAppendCodeIfExist);
  finally
    ilist.Free;
  end;

end;

function TRMCodeGenEngine.AddFunctionCode(aFunctionName,
  aFunctionDefine: string; aCode: TStringList;
  aAppendCodeIfExist: Boolean): integer;
var
  i, lPosBeg, lPosEnd, lInsPos: integer;
  lstr, tmpstr, laddcode, s: string;
  lLeftStr, lRightStr: string;
  lFunctionDesc, lfd: TJvInterpreterFunctionDesc;
  lclist: TStringList;
  eb: Boolean;

  function _AddMainFunction: integer;
  begin
    Result := 0;
    with Script do
    begin
      if (Count = 0) or ((Count > 0) and (Trim(CommaText) = '')) then
      begin
        Insert(0, 'Unit Report;');
        Insert(1, '');
        Result := Add('procedure Main;');
        Append('begin');
        Append('');
        Append('end;');
        Append('');
        Append('end.');
      end;
    end;
  end;

  procedure _TrimScript(aList: TStrings);
  var
    s: string;
  begin
    if lclist.Count > 0 then
    begin
      s := Trim(lclist[lclist.Count - 1]);
      if cmp(Trim(lclist[0]), 'begin') and
        (cmp(s, 'end') or cmp(s, 'end;')) then
      begin
        lclist.Delete(0);
        lclist.Delete(lclist.Count - 1);
      end;
    end;
  end;

begin
  Result := -1;
  laddcode := '';

  if (aFunctionName = '') or
    ((aFunctionDefine = '') and not aAppendCodeIfExist) then
    Exit;

  CompileScript;
  with ScriptEngine do
  begin
    lfd := GetFunDesc(aFunctionName);
    eb := lfd <> nil;
    if (eb and not aAppendCodeIfExist) then
      Exit;

    lclist := TStringList.Create;
    try
      if aCode <> nil then
      begin
        lclist.Assign(aCode);
      //  DeleteEmptyLines(lclist);  { TODO -oswitch -c :  2006-4-20 21:01:11 }

        _TrimScript(lclist);
      end;

      if not eb then //������������
      begin
        lFunctionDesc := GetFunDesc('Main'); //����������
        if lFunctionDesc <> nil then //����������
        begin
          lfd := GetFunDesc(Tag_InitProcedure);
          if lfd <> nil then //�����InitializeComponentǰ
            lFunctionDesc := lfd;

          lstr := Script.Text;
          lPosBeg := lFunctionDesc.PosBeg;
          //lPosEnd := lFunctionDesc.PosEnd;
          tmpstr := StrLeft(lstr, lPosBeg);
          i := StrLastPos('PROCEDURE', UpperCase(tmpstr));
          //ȥ�� Procedureǰ��Ŀո�,ʹ����λ�ö�λ����һ��.
          lInsPos := StrLastPos(AnsiCrLf, StrLeft(lstr, i)); //�����һ���س���λ��Ϊ����λ��
          s := Copy(tmpstr, lInsPos, i - lInsPos);
          if Trim(s) <> '' then //��������ǰһ���س���֮�仹���ַ�
          begin
            lInsPos := i;
          end;

          //Ҫ��ӵĳ������
          if aCode <> nil then
            s := lclist.Text
          else
            s := '' + AnsiCrLf;

          tmpstr := Copy(lstr, lInsPos, 2);
          if tmpstr <> AnsiCrLf then
            lLeftStr := AnsiCrLf
          else
            if Copy(lstr, lInsPos - 2, 2) <> AnsiCrLf then
              lLeftStr := AnsiCrLf
            else
              lLeftStr := '';

          if tmpstr <> AnsiCrLf then
            lRightStr := AnsiCrLf
          else
            lRightStr := '';


          laddcode := lLeftStr + AnsiCrLf + aFunctionDefine + AnsiCrLf + 'begin' + AnsiCrLf
            + s
            + 'end;' + AnsiCrLf + lRightStr;

          System.Insert(laddcode, lstr, lInsPos);
          Script.Text := lstr;
          Result := lInsPos + Length(lLeftStr + AnsiCrLf + aFunctionDefine + AnsiCrLf + 'begin');
        end else
        begin
          lInsPos := _AddMainFunction; //���������
          Script.Insert(lInsPos, '');
          Script.Insert(lInsPos, 'end;');
          for i := lclist.Count - 1 to 0 do
          begin
            Script.Insert(lInsPos, lclist[i]);
          end;
          Script.Insert(lInsPos, 'begin');
          Script.Insert(lInsPos, aFunctionDefine);
          Script.Insert(lInsPos, '');

        end;
      end
      else //�����Ѿ�����
      begin
        lstr := Script.Text; //ԭ���ĳ������
        laddcode := lclist.Text; //Ҫ��ӵĳ������
        //lPosBeg := lfd.PosBeg;
        lPosEnd := lfd.PosEnd;
        lInsPos := StrILastPos('end', copy(lstr, 0, lPosEnd));
        System.Insert(laddcode, lstr, lInsPos);
        Script.Text := lstr;

      end;
      ScriptCompiled := False;
    finally
      lclist.Free;
    end;
  end;

  Modified;
  DoScriptChanged;
end;

function TRMCodeGenEngine.CompileScript: boolean;
begin
  Result := True;
  if ScriptCompiled then
    Exit;

  if not ScriptCompiled then
    DoGetScript;

  if (ScriptText <> '') then
  begin
    try
      ScriptEngine.Compile;
      ScriptCompiled := True;
    except //���γ�����Ϣ
      on E: Exception do
        Result := False;
    end;
  end;
end;

constructor TRMCodeGenEngine.Create;
begin
  inherited;

end;

destructor TRMCodeGenEngine.Destroy;
begin
  SetScript(nil);
  if FScriptInterpreter <> nil then
    FScriptInterpreter.Free;
  inherited;
end;

function TRMCodeGenEngine.FunctionExists(
  const aFunctionName: string): Boolean;
begin
  Result := GetFunDesc(aFunctionName) <> nil;
end;

function TRMCodeGenEngine.GetFunctionPos(
  const aFunctionName: string): integer;
var
  i, lPosBeg, lPosEnd: integer;
  lstr: string;
  lFunctionDesc: TJvInterpreterFunctionDesc;
begin
  Result := -1;

  if (aFunctionName = '') then Exit;

  lFunctionDesc := GetFunDesc(aFunctionName);
  with ScriptEngine do
  begin
    if lFunctionDesc <> nil then
    begin
      lPosBeg := lFunctionDesc.PosBeg;
      lPosEnd := lFunctionDesc.PosEnd;
      lstr := Copy(Script.Text, lPosBeg, lPosEnd - lPosBeg);
      i := StrIPos('BEGIN', lstr);
      Result := lPosBeg + 5 + i;
    end;
  end;
end;

function TRMCodeGenEngine.GetFunDesc(
  ASrcFunName: string): TJvInterpreterFunctionDesc;
begin
  Result := nil;
  if Script.Text = '' then Exit;

  CompileScript;
  with THackJvInterpreterAdapter(ScriptEngine.Adapter) do
  begin
    Result := FindFunDesc(ScriptEngine.CurUnitName, ASrcFunName);
  end;
end;

function TRMCodeGenEngine.GetFunctionCode(aFunctionName: string): string;
var
  lColdeList: TStringList;
begin
  lColdeList := TStringList.Create;
  try
    GetFunctionCode(aFunctionName, lColdeList);
    Result := lColdeList.Text;
  finally
    lColdeList.Free;
  end;

end;

procedure TRMCodeGenEngine.GetFunctionCode(aFunctionName: string; aCode: TStringList);
var
  lFunctionDesc: TJvInterpreterFunctionDesc;
  s: string;
  lbeg, lend: integer;
begin

  if (aFunctionName = '') then
    Exit;
  lFunctionDesc := GetFunDesc(aFunctionName);

  if lFunctionDesc = nil then Exit;

  if not Assigned(aCode) then
    aCode := TStringList.Create
  else
    aCode.Clear;

  if lFunctionDesc <> nil then
  begin
    lbeg := lFunctionDesc.PosBeg;
    lend := lFunctionDesc.PosEnd;
    s := copy(Script.Text, lbeg, lend - lbeg);
    s := StrAfter('begin', s);
    s := StrBefore('end', s);
    if Trim(s) = '' then
      s := '';
    aCode.Text := s;
    DeleteEmptyLines(aCode);
  end;
end;

function TRMCodeGenEngine.GetScript: TStrings;
begin
  Result := ScriptEngine.Pas;
end;

function TRMCodeGenEngine.GetScriptInterpreter: TJvInterpreterProgram;
begin
  if FScriptInterpreter = nil then
    FScriptInterpreter := TJvInterpreterProgram.Create(nil);
  Result := FScriptInterpreter;
end;

procedure TRMCodeGenEngine.SetScript(const Value: TStrings);
begin
  if Script <> Value then
  begin
    if Value <> nil then
    begin
      Script.Assign(Value);
      Modified;
    end
  end;
end;

function TRMCodeGenEngine.RenameFunction(const CurName, NewName: string): Boolean;
var
  lFuncDesc, lNewFuncDesc: TJvInterpreterFunctionDesc;
  lstr, s, stg: string;
  lbeg, i: integer;
begin
  Result := False;

  if (CurName = '') or (NewName = '') or Cmp(CurName, NewName) then
    Exit;

  CompileScript;

  lFuncDesc := GetFunDesc(CurName);
  if lFuncDesc = nil then Exit;

  lNewFuncDesc := GetFunDesc(NewName);
  if lNewFuncDesc <> nil then Exit;

  lstr := Script.Text;
  if lFuncDesc.ResTyp = varEmpty then
    stg := 'procedure'
  else
    stg := 'function';
  lbeg := lFuncDesc.PosBeg;

  s := StrLeft(lstr, lbeg);
  i := StrILastPos(stg, s);
  s := copy(lstr, i, lbeg - i);
  s := StringReplace(s, CurName, NewName, [rfIgnoreCase]);
  System.Delete(lstr, i, lbeg - i);
  System.Insert(s, lstr, i);
  Script.Text := lstr;
  Result := True;

  Modified;
  DoScriptChanged;
end;

function TRMCodeGenEngine.DeleteFunction(
  const aFunctionName: string): Boolean;
begin
  Result := False;

  //Modified;
  DoScriptChanged;
end;


procedure TRMCodeGenEngine.Modified;
begin
  ScriptCompiled := False;
end;

function TRMCodeGenEngine.GetScriptText: string;
begin
  Result := Script.Text;
end;

procedure TRMCodeGenEngine.SetScriptText(const Value: string);
begin
  Script.Text := Value;
  Modified;
end;

procedure TRMCodeGenEngine.DoGetScript;
begin
  if Assigned(FOnGetScript) then
  begin
    FOnGetScript(Script);

    if Script.Text = '' then
      raise Exception.Create('Script Can''t be nil!');

    Modified;
  end;
end;

procedure TRMCodeGenEngine.DoScriptChanged;
begin
  if Assigned(FOnScriptChanged) then
  begin
    FOnScriptChanged(Self);
  end;
end;

initialization

finalization

end.

