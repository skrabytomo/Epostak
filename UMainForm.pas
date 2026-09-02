unit UMainForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, IniFiles, FileCtrl,
  EpostakClient, EpostakDemoCreds;

type
  TFormMain = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    edtBaseURL: TEdit;
    edtParticipantId: TEdit;
    edtClientId: TEdit;
    edtClientSecret: TEdit;
    btnSaveConfig: TButton;
    btnUseFirmA: TButton;
    btnUseFirmB: TButton;
    edtXMLFile: TEdit;
    btnBrowseXML: TButton;
    edtReceiverId: TEdit;
    btnSend: TButton;
    lvInbox: TListView;
    edtSaveFolder: TEdit;
    btnBrowseFolder: TButton;
    btnCheckInbox: TButton;
    btnDownloadSelected: TButton;
    btnAcknowledgeSelected: TButton;
    memLog: TMemo;
    dlgOpenXML: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSaveConfigClick(Sender: TObject);
    procedure btnUseFirmAClick(Sender: TObject);
    procedure btnUseFirmBClick(Sender: TObject);
    procedure btnBrowseXMLClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnBrowseFolderClick(Sender: TObject);
    procedure btnCheckInboxClick(Sender: TObject);
    procedure btnDownloadSelectedClick(Sender: TObject);
    procedure btnAcknowledgeSelectedClick(Sender: TObject);
    procedure btnUseSandboxClick(Sender: TObject);
    procedure btnUseProductionClick(Sender: TObject);
  private
    FClient: TEpostakClient;
    FInboxItems: TEpostakDocumentListResult;
    function ConfigFileName: string;
    procedure Log(const AMsg: string);
    function MakeClient: TEpostakClient;
    function LoadRawBytesFromFile(const AFileName: string): string;
    function BuildSampleInvoice(const ADocumentId, AIssueDate, ADueDate,
      ASenderId, AReceiverId: string): string;
    procedure RefreshInboxList;
    function GetSelectedDocId: string;
    function GetSelectedDocIds: TStringList;
    procedure SetupColumns;
    function ValidateUBLXml(const AXml: string): string;
    function FormatISODateTime(const AISO: string): string;
    function ShortDocType(const AFullType: string): string;
  end;

var
  FormMain: TFormMain;

const
  DOC_TYPE_ID = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice' +
    '##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1';
  PROCESS_ID  = 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

implementation

{$R *.dfm}

function TFormMain.ConfigFileName: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

procedure TFormMain.Log(const AMsg: string);
begin
  memLog.Lines.Add(AMsg);
  memLog.SelStart := Length(memLog.Text);
  memLog.SelLength := 0;
  SendMessage(memLog.Handle, EM_SCROLLCARET, 0, 0);
  Application.ProcessMessages;
end;

function TFormMain.MakeClient: TEpostakClient;
{ Vrati cached klient ak credentialy nesmenili, inak vytvori noveho.
  Znizuje pocet auth volani — pomaha proti rate limitu (429). }
var
  NeedNew: Boolean;
begin
  if (edtClientId.Text = '') or (edtClientSecret.Text = '') then
    raise Exception.Create('Vyplnte ClientId a ClientSecret (alebo pouzite tlacidlo Firma A / Firma B).');
  if edtParticipantId.Text = '' then
    raise Exception.Create('Vyplnte vlastne Participant Id.');
    
  NeedNew := True;
  if FClient <> nil then
  begin
    NeedNew := not FClient.ConfigMatches(edtBaseURL.Text, edtClientId.Text,
      edtClientSecret.Text, edtParticipantId.Text);
    if NeedNew then
    begin
      FClient.Free;
      FClient := nil;
    end;
  end;
  
  if FClient = nil then
  begin
    FClient := TEpostakClient.Create(edtBaseURL.Text, edtClientId.Text,
      edtClientSecret.Text, edtParticipantId.Text);
    Log('Vytvoreny novy klient (auth sa vykona pri prvom volani).');
  end;
  
  Result := FClient;
end;

function TFormMain.LoadRawBytesFromFile(const AFileName: string): string;
var
  FS: TFileStream;
  BOMSize: Integer;
begin
  Result := '';
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size > 0 then
    begin
      SetLength(Result, FS.Size);
      FS.ReadBuffer(Result[1], FS.Size);

      { Odstranime UTF-8 BOM (EF BB BF) ak je pritomny }
      BOMSize := 0;
      if (Length(Result) >= 3) and
         (Ord(Result[1]) = $EF) and
         (Ord(Result[2]) = $BB) and
         (Ord(Result[3]) = $BF) then
        BOMSize := 3;

      if BOMSize > 0 then
        Delete(Result, 1, BOMSize);
    end;
  finally
    FS.Free;
  end;
end;

function TFormMain.ValidateUBLXml(const AXml: string): string;
{ Jednoducha client-side validacia — kontroluje pritomnost klucovych elementov.
  Plna Peppol validacia vyzaduje XSD + Schematron, co je mimo rozsah tejto appky. }
begin
  Result := '';
  if Pos('<cac:PostalAddress>', AXml) = 0 then
    Result := Result + 'Chyba: Chyba PostalAddress (predavatel/odberatel).'#13#10;
  if Pos('<cac:PartyTaxScheme>', AXml) = 0 then
    Result := Result + 'Chyba: Chyba PartyTaxScheme (VAT identifikator).'#13#10;
  if Pos('<cac:PartyLegalEntity>', AXml) = 0 then
    Result := Result + 'Chyba: Chyba PartyLegalEntity (CompanyID).'#13#10;
  if Pos('<cbc:InvoiceTypeCode>', AXml) = 0 then
    Result := Result + 'Chyba: Chyba InvoiceTypeCode.'#13#10;
  if Pos('<cbc:DocumentCurrencyCode>', AXml) = 0 then
    Result := Result + 'Chyba: Chyba DocumentCurrencyCode.'#13#10;
end;

function TFormMain.BuildSampleInvoice(const ADocumentId, AIssueDate, ADueDate,
  ASenderId, AReceiverId: string): string;

  function DicOf(const AParticipantId: string): string;
  var
    P: Integer;
  begin
    P := Pos(':', AParticipantId);
    if P > 0 then
      Result := Copy(AParticipantId, P + 1, MaxInt)
    else
      Result := AParticipantId;
  end;

begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" ' +
    'xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" ' +
    'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">' +
    '<cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>' +
    '<cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>' +
    '<cbc:ID>' + ADocumentId + '</cbc:ID>' +
    '<cbc:IssueDate>' + AIssueDate + '</cbc:IssueDate>' +
    '<cbc:DueDate>' + ADueDate + '</cbc:DueDate>' +
    '<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>' +
    '<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>' +
    '<cbc:BuyerReference>REF-' + ADocumentId + '</cbc:BuyerReference>' +
    '<cac:AccountingSupplierParty><cac:Party>' +
    '<cbc:EndpointID schemeID="0245">' + DicOf(ASenderId) + '</cbc:EndpointID>' +
    '<cac:PostalAddress><cbc:StreetName>Hlavna 1</cbc:StreetName>' +
    '<cbc:CityName>Bratislava</cbc:CityName><cbc:PostalZone>81101</cbc:PostalZone>' +
    '<cac:Country><cbc:IdentificationCode>SK</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyTaxScheme><cbc:CompanyID>SK' + DicOf(ASenderId) + '</cbc:CompanyID>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>Odosielatel s.r.o.</cbc:RegistrationName>' +
    '<cbc:CompanyID schemeID="0245">' + DicOf(ASenderId) + '</cbc:CompanyID></cac:PartyLegalEntity>' +
    '</cac:Party></cac:AccountingSupplierParty>' +
    '<cac:AccountingCustomerParty><cac:Party>' +
    '<cbc:EndpointID schemeID="0245">' + DicOf(AReceiverId) + '</cbc:EndpointID>' +
    '<cac:PostalAddress><cbc:StreetName>Namestie 5</cbc:StreetName>' +
    '<cbc:CityName>Zilina</cbc:CityName><cbc:PostalZone>01001</cbc:PostalZone>' +
    '<cac:Country><cbc:IdentificationCode>SK</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyTaxScheme><cbc:CompanyID>SK' + DicOf(AReceiverId) + '</cbc:CompanyID>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>Odberatel s.r.o.</cbc:RegistrationName>' +
    '<cbc:CompanyID schemeID="0245">' + DicOf(AReceiverId) + '</cbc:CompanyID></cac:PartyLegalEntity>' +
    '</cac:Party></cac:AccountingCustomerParty>' +
    '<cac:PaymentMeans><cbc:PaymentMeansCode>30</cbc:PaymentMeansCode>' +
    '<cac:PayeeFinancialAccount><cbc:ID>SK6807200002891987426353</cbc:ID>' +
    '</cac:PayeeFinancialAccount></cac:PaymentMeans>' +
    '<cac:TaxTotal><cbc:TaxAmount currencyID="EUR">19.00</cbc:TaxAmount>' +
    '<cac:TaxSubtotal><cbc:TaxableAmount currencyID="EUR">95.00</cbc:TaxableAmount>' +
    '<cbc:TaxAmount currencyID="EUR">19.00</cbc:TaxAmount>' +
    '<cac:TaxCategory><cbc:ID>S</cbc:ID><cbc:Percent>20</cbc:Percent>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:TaxCategory>' +
    '</cac:TaxSubtotal></cac:TaxTotal>' +
    '<cac:LegalMonetaryTotal>' +
    '<cbc:LineExtensionAmount currencyID="EUR">95.00</cbc:LineExtensionAmount>' +
    '<cbc:TaxExclusiveAmount currencyID="EUR">95.00</cbc:TaxExclusiveAmount>' +
    '<cbc:TaxInclusiveAmount currencyID="EUR">114.00</cbc:TaxInclusiveAmount>' +
    '<cbc:PayableAmount currencyID="EUR">114.00</cbc:PayableAmount>' +
    '</cac:LegalMonetaryTotal>' +
    '<cac:InvoiceLine><cbc:ID>1</cbc:ID>' +
    '<cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>' +
    '<cbc:LineExtensionAmount currencyID="EUR">95.00</cbc:LineExtensionAmount>' +
    '<cac:Item><cbc:Name>Testovacia polozka</cbc:Name>' +
    '<cac:ClassifiedTaxCategory><cbc:ID>S</cbc:ID><cbc:Percent>20</cbc:Percent>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:ClassifiedTaxCategory></cac:Item>' +
    '<cac:Price><cbc:PriceAmount currencyID="EUR">95.00</cbc:PriceAmount></cac:Price>' +
    '</cac:InvoiceLine>' +
    '</Invoice>';
end;

function TFormMain.FormatISODateTime(const AISO: string): string;
var
  DT: TDateTime;
begin
  try
    DT := EncodeDate(
      StrToIntDef(Copy(AISO, 1, 4), 2026),
      StrToIntDef(Copy(AISO, 6, 2), 1),
      StrToIntDef(Copy(AISO, 9, 2), 1)
    ) + EncodeTime(
      StrToIntDef(Copy(AISO, 12, 2), 0),
      StrToIntDef(Copy(AISO, 15, 2), 0),
      StrToIntDef(Copy(AISO, 18, 2), 0),
      0
    );
    Result := FormatDateTime('dd.mm.yyyy hh:nn', DT);
  except
    Result := AISO;
  end;
end;

function TFormMain.ShortDocType(const AFullType: string): string;
var
  P: Integer;
begin
  Result := AFullType;
  P := Pos('::', Result);
  if P > 0 then
  begin
    Result := Copy(Result, P + 2, MaxInt);
    P := Pos('##', Result);
    if P > 0 then
      Result := Copy(Result, 1, P - 1);
  end;
  if Result = '' then Result := AFullType;
end;

procedure TFormMain.SetupColumns;
begin
  lvInbox.ViewStyle := vsReport;
  lvInbox.Columns.Clear;
  with lvInbox.Columns.Add do begin Caption := '#'; Width := 30; Alignment := taRightJustify; end;
  with lvInbox.Columns.Add do begin Caption := 'Cislo dokumentu'; Width := 180; end;
  with lvInbox.Columns.Add do begin Caption := 'Odosielatel'; Width := 130; end;
  with lvInbox.Columns.Add do begin Caption := 'Prijemca'; Width := 130; end;
  with lvInbox.Columns.Add do begin Caption := 'Typ'; Width := 80; end;
  with lvInbox.Columns.Add do begin Caption := 'Vytvorene'; Width := 120; end;
  with lvInbox.Columns.Add do begin Caption := 'Stav'; Width := 90; end;
end;

procedure TFormMain.RefreshInboxList;
var
  i: Integer;
  Item: TListItem;
begin
  lvInbox.Items.Clear;
  for i := 0 to High(FInboxItems.Documents) do
  begin
    Item := lvInbox.Items.Add;
    Item.Caption := IntToStr(i + 1);
    Item.SubItems.Add(FInboxItems.Documents[i].DocumentId);
    Item.SubItems.Add(FInboxItems.Documents[i].SenderParticipantId);
    Item.SubItems.Add(FInboxItems.Documents[i].ReceiverParticipantId);
    Item.SubItems.Add(ShortDocType(FInboxItems.Documents[i].DocumentTypeId));
    Item.SubItems.Add(FormatISODateTime(FInboxItems.Documents[i].CreationDateTime));
    Item.SubItems.Add('RECEIVED');
  end;
end;

function TFormMain.GetSelectedDocId: string;
begin
  Result := '';
  if (lvInbox.Selected <> nil) then
    Result := lvInbox.Selected.SubItems[0];
end;

function TFormMain.GetSelectedDocIds: TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to lvInbox.Items.Count - 1 do
    if lvInbox.Items[i].Selected then
      Result.Add(lvInbox.Items[i].SubItems[0]);
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  SetupColumns;
  edtBaseURL.Text := EPOSTAK_SANDBOX_BASE_URL;
  edtParticipantId.Text := FIRM_A_ID;
  edtClientId.Text := FIRM_A_CLIENT_ID;
  edtClientSecret.Text := FIRM_A_CLIENT_SECRET;
  edtReceiverId.Text := FIRM_B_ID;
  edtSaveFolder.Text := ExtractFilePath(Application.ExeName) + 'inbox';

  if FileExists(ConfigFileName) then
  begin
    Ini := TIniFile.Create(ConfigFileName);
    try
      edtBaseURL.Text := Ini.ReadString('EPOSTAK', 'BaseURL', edtBaseURL.Text);
      edtParticipantId.Text := Ini.ReadString('EPOSTAK', 'ParticipantId', edtParticipantId.Text);
      edtClientId.Text := Ini.ReadString('EPOSTAK', 'ClientId', edtClientId.Text);
      edtClientSecret.Text := Ini.ReadString('EPOSTAK', 'ClientSecret', edtClientSecret.Text);
      edtReceiverId.Text := Ini.ReadString('EPOSTAK', 'ReceiverId', edtReceiverId.Text);
      edtSaveFolder.Text := Ini.ReadString('EPOSTAK', 'SaveFolder', edtSaveFolder.Text);
      Log('Konfiguracia nacitana z ' + ConfigFileName);
    finally
      Ini.Free;
    end;
  end;

  dlgOpenXML.Filter := 'XML subory (*.xml)|*.xml|Vsetky subory (*.*)|*.*';
end;

procedure TFormMain.btnSaveConfigClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFileName);
  try
    Ini.WriteString('EPOSTAK', 'BaseURL', edtBaseURL.Text);
    Ini.WriteString('EPOSTAK', 'ParticipantId', edtParticipantId.Text);
    Ini.WriteString('EPOSTAK', 'ClientId', edtClientId.Text);
    Ini.WriteString('EPOSTAK', 'ClientSecret', edtClientSecret.Text);
    Ini.WriteString('EPOSTAK', 'ReceiverId', edtReceiverId.Text);
    Ini.WriteString('EPOSTAK', 'SaveFolder', edtSaveFolder.Text);
    Log('Konfiguracia ulozena do ' + ConfigFileName);
  finally
    Ini.Free;
  end;
end;

procedure TFormMain.btnUseFirmAClick(Sender: TObject);
begin
  edtParticipantId.Text := FIRM_A_ID;
  edtClientId.Text := FIRM_A_CLIENT_ID;
  edtClientSecret.Text := FIRM_A_CLIENT_SECRET;
  edtReceiverId.Text := FIRM_B_ID;
  Log('Nastavene ako Firma A. Pre odoslanie kliknite ODOSLAT (prijemca = Firma B).');
end;

procedure TFormMain.btnUseFirmBClick(Sender: TObject);
begin
  edtParticipantId.Text := FIRM_B_ID;
  edtClientId.Text := FIRM_B_CLIENT_ID;
  edtClientSecret.Text := FIRM_B_CLIENT_SECRET;
  edtReceiverId.Text := FIRM_A_ID;
  if FIRM_B_CLIENT_SECRET = '' then
    Log('POZOR: FIRM_B_CLIENT_SECRET je prazdny v EpostakDemoCreds.pas.')
  else
    Log('Nastavene ako Firma B. Pre prijem kliknite SKONTROLOVAT INBOX. Pre odoslanie na Firmu A kliknite ODOSLAT.');
end;

procedure TFormMain.btnBrowseXMLClick(Sender: TObject);
begin
  if dlgOpenXML.Execute then
    edtXMLFile.Text := dlgOpenXML.FileName;
end;

procedure TFormMain.btnBrowseFolderClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtSaveFolder.Text;
  if SelectDirectory('Vyberte priecinok pre stahovanie', '', Dir) then
    edtSaveFolder.Text := Dir;
end;

procedure TFormMain.btnSendClick(Sender: TObject);
var
  Client: TEpostakClient;
  UblXml, DocId, ValidationErrors: string;
begin
  if Trim(edtBaseURL.Text) = '' then
  begin
    Log('CHYBA: Vyplnte Base URL.');
    Exit;
  end;

  if Trim(edtParticipantId.Text) = '' then
  begin
    Log('CHYBA: Vyplnte Participant ID (odosielatela).');
    Exit;
  end;

  if Trim(edtReceiverId.Text) = '' then
  begin
    Log('CHYBA: Vyplnte Prijemcu (Participant ID prijemcu).');
    Exit;
  end;

  if Trim(edtXMLFile.Text) = '' then
  begin
    Log('Generujem testovaciu fakturu inline...');
    UblXml := BuildSampleInvoice(
      'SANDBOX-' + FormatDateTime('yyyy-mm-dd-hhnnss', Now),
      FormatDateTime('yyyy-mm-dd', Now),
      FormatDateTime('yyyy-mm-dd', Now + 30),
      edtParticipantId.Text,
      edtReceiverId.Text);
  end
  else
  begin
    if not FileExists(edtXMLFile.Text) then
    begin
      Log('CHYBA: Subor neexistuje: ' + edtXMLFile.Text);
      Exit;
    end;
    Log('Nacitavam XML zo suboru: ' + edtXMLFile.Text);
    UblXml := LoadRawBytesFromFile(edtXMLFile.Text);
  end;

  if Trim(UblXml) = '' then
  begin
    Log('CHYBA: XML je prazdny.');
    Exit;
  end;

  { Client-side validacia pred odoslanim }
  ValidationErrors := ValidateUBLXml(UblXml);
  if ValidationErrors <> '' then
  begin
    Log('UPOZORNENIE: XML neobsahuje vsetky povinne elementy pre Peppol:');
    Log(ValidationErrors);
    Log('Odoslanie moze zlyhat s chybou 422. Pokracovat? (v produkcii zastavte a opravte XML)');
  end;

  try
    Client := MakeClient;
  except
    on E: Exception do
    begin
      Log('CHYBA: ' + E.Message);
      Exit;
    end;
  end;

  DocId := 'SANDBOX-' + FormatDateTime('yyyy-mm-dd-hhnnss', Now) + '-' + IntToStr(Random(1000));
  Log('Odosielam dokument ' + DocId + '...');
  try
    DocId := Client.SendInvoice(
      DocId,
      'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice' +
        '##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1',
      'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
      edtParticipantId.Text,
      edtReceiverId.Text,
      UblXml
    );
    if DocId = '' then
      ShowMessage('Tento dokument uz bol odoslany (duplicitny documentId).'#13#10 +
        'Zmente <cbc:ID> v XML subore alebo pouzite prazdne pole pre auto-generovanie.')
    else
      Log('OK — dokument odoslany. providerDocumentId: ' + DocId);
  except
    on E: Exception do
    begin
      if Pos('HTTP 422', E.Message) > 0 then
      begin
        Log('CHYBA 422: XML nepreslo Peppol validaciou.');
        Log('Detail: ' + E.Message);
        Log('Validator: https://peppol.helger.com/public/menuitem-validation-bis3');
      end
      else if Pos('HTTP 502', E.Message) > 0 then
      begin
        Log('CHYBA 502: Server nedokazal dorucit dokument.');
        Log('Riesenie: Overte ci prijemcove Participant ID existuje v Peppol.');
      end
      else
        Log('CHYBA: ' + E.Message);
    end;
  end;
end;

procedure TFormMain.btnCheckInboxClick(Sender: TObject);
var
  Client: TEpostakClient;
begin
  try
    Client := MakeClient;
  except
    on E: Exception do
    begin
      Log('CHYBA: ' + E.Message);
      Exit;
    end;
  end;

  Log('Kontrolujem inbox pre ' + edtParticipantId.Text + '...');
  try
    FInboxItems := Client.ListReceived('RECEIVED', 100);
    RefreshInboxList;
    Log('Najdenych ' + IntToStr(Length(FInboxItems.Documents)) + ' dokumentov.');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;

procedure TFormMain.btnDownloadSelectedClick(Sender: TObject);
var
  Client: TEpostakClient;
  DocId, XML, SavePath: string;
begin
  DocId := GetSelectedDocId;
  if DocId = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument v zozname.');
    Exit;
  end;

  try
    Client := MakeClient;
  except
    on E: Exception do
    begin
      Log('CHYBA: ' + E.Message);
      Exit;
    end;
  end;

  ForceDirectories(edtSaveFolder.Text);
  SavePath := edtSaveFolder.Text;
  if (SavePath <> '') and (SavePath[Length(SavePath)] <> '\') then
    SavePath := SavePath + '\';
  SavePath := SavePath + DocId + '.xml';

  Log('Stahujem ' + DocId + '...');
  try
    XML := Client.GetDocumentXML(DocId);
    SaveRawBytesToFile(SavePath, XML);
    Log('ULOZENE: ' + SavePath + ' (' + IntToStr(Length(XML)) + ' bajtov)');
  except
    on E: Exception do
      Log('CHYBA pri stahovani: ' + E.Message);
  end;
end;

procedure TFormMain.btnAcknowledgeSelectedClick(Sender: TObject);
var
  Client: TEpostakClient;
  DocIds: TStringList;
  i: Integer;
  OkCount, FailCount: Integer;
begin
  DocIds := GetSelectedDocIds;
  try
    if DocIds.Count = 0 then
    begin
      Log('CHYBA: Najprv vyberte aspon jeden dokument (Ctrl+klik pre viac).');
      Exit;
    end;

    try
      Client := MakeClient;
    except
      on E: Exception do
      begin
        Log('CHYBA: ' + E.Message);
        Exit;
      end;
    end;

    Log('Potvrdzujem ' + IntToStr(DocIds.Count) + ' dokumentov...');
    OkCount := 0;
    FailCount := 0;
    for i := 0 to DocIds.Count - 1 do
    begin
      try
        Client.AcknowledgeDocument(DocIds[i]);
        Inc(OkCount);
        Log('  OK: ' + DocIds[i]);
        if i < DocIds.Count - 1 then
          Sleep(1000);
      except
        on E: Exception do
        begin
          Inc(FailCount);
          Log('  CHYBA [' + DocIds[i] + ']: ' + E.Message);
        end;
      end;
    end;
    Log('HOTOVO: ' + IntToStr(OkCount) + ' OK, ' + IntToStr(FailCount) + ' chyb.');
    btnCheckInboxClick(nil);
  finally
    DocIds.Free;
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  if FClient <> nil then
  begin
    try
      FClient.RevokeToken;
    except
    end;
    FreeAndNil(FClient);
  end;
end;

procedure TFormMain.btnUseSandboxClick(Sender: TObject);
begin
  edtBaseURL.Text := EPOSTAK_SANDBOX_BASE_URL;
  Log('URL prepnuta na SANDBOX: ' + EPOSTAK_SANDBOX_BASE_URL);
end;

procedure TFormMain.btnUseProductionClick(Sender: TObject);
begin
  edtBaseURL.Text := EPOSTAK_PRODUCTION_BASE_URL;
  Log('URL prepnuta na PRODUKCIU: ' + EPOSTAK_PRODUCTION_BASE_URL);
  Log('POZOR: Uistite sa, ze mate produkcne ClientId a ClientSecret.');
end;

end.
