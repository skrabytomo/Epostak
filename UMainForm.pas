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
    procedure btnSaveConfigClick(Sender: TObject);
    procedure btnUseFirmAClick(Sender: TObject);
    procedure btnUseFirmBClick(Sender: TObject);
    procedure btnBrowseXMLClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnBrowseFolderClick(Sender: TObject);
    procedure btnCheckInboxClick(Sender: TObject);
    procedure btnDownloadSelectedClick(Sender: TObject);
    procedure btnAcknowledgeSelectedClick(Sender: TObject);
  private
    FInboxItems: TEpostakDocumentListResult;
    function ConfigFileName: string;
    procedure Log(const AMsg: string);
    function MakeClient: TEpostakClient;
    function LoadRawBytesFromFile(const AFileName: string): string;
    function BuildSampleInvoice(const ADocumentId, AIssueDate, ADueDate,
      ASenderId, AReceiverId: string): string;
    procedure RefreshInboxList;
    function GetSelectedDocId: string;
    procedure SetupColumns;
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
  SendMessage(memLog.Handle, EM_LINESCROLL, 0, MaxInt);
  Application.ProcessMessages;
end;

function TFormMain.MakeClient: TEpostakClient;
begin
  if (edtClientId.Text = '') or (edtClientSecret.Text = '') then
    raise Exception.Create('Vyplnte ClientId a ClientSecret (alebo pouzite tlacidlo Firma A / Firma B).');
  if edtParticipantId.Text = '' then
    raise Exception.Create('Vyplnte vlastne Participant Id.');
  Result := TEpostakClient.Create(edtBaseURL.Text, edtClientId.Text,
    edtClientSecret.Text, edtParticipantId.Text);
end;

function TFormMain.LoadRawBytesFromFile(const AFileName: string): string;
var
  FS: TFileStream;
begin
  Result := '';
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size > 0 then
    begin
      SetLength(Result, FS.Size);
      FS.ReadBuffer(Result[1], FS.Size);
    end;
  finally
    FS.Free;
  end;
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

procedure TFormMain.SetupColumns;
begin
  lvInbox.ViewStyle := vsReport;
  lvInbox.Columns.Clear;
  with lvInbox.Columns.Add do begin Caption := 'DocumentId'; Width := 260; end;
  with lvInbox.Columns.Add do begin Caption := 'Odosielatel'; Width := 150; end;
  with lvInbox.Columns.Add do begin Caption := 'Typ dokumentu'; Width := 120; end;
  with lvInbox.Columns.Add do begin Caption := 'Vytvorene'; Width := 140; end;
end;

procedure TFormMain.RefreshInboxList;
var
  i: Integer;
  Item: TListItem;
begin
  lvInbox.Items.Clear;
  for i := 0 to High(FInboxItems) do
  begin
    Item := lvInbox.Items.Add;
    Item.Caption := FInboxItems.Documents[i].DocumentId;
    Item.SubItems.Add(FInboxItems.Documents[i].SenderParticipantId);
    Item.SubItems.Add(FInboxItems.Documents[i].DocumentTypeId);
    Item.SubItems.Add(FInboxItems.Documents[i].CreationDateTime);
  end;
end;

function TFormMain.GetSelectedDocId: string;
begin
  Result := '';
  if (lvInbox.Selected <> nil) then
    Result := lvInbox.Selected.Caption;
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
  Log('Nastavene ako Firma A (odosielatel). Prijemca = Firma B.');
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
    Log('Nastavene ako Firma B (prijemca). Odosielatel = Firma A.');
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
  XML, DocumentId, ProviderDocId: string;
begin
  if edtReceiverId.Text = '' then
  begin
    Log('CHYBA: Vyplnte Participant Id prijemcu.');
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

  try
    DocumentId := 'FA-' + FormatDateTime('yyyymmdd-hhnnss', Now);

    if (edtXMLFile.Text <> '') and FileExists(edtXMLFile.Text) then
    begin
      Log('Nacitavam XML zo suboru: ' + edtXMLFile.Text);
      XML := LoadRawBytesFromFile(edtXMLFile.Text);
    end
    else
    begin
      Log('Ziaden subor - pouzivam vzorovu testovaciu fakturu.');
      XML := BuildSampleInvoice(DocumentId, FormatDateTime('yyyy-mm-dd', Now),
        FormatDateTime('yyyy-mm-dd', Now + 14), edtParticipantId.Text, edtReceiverId.Text);
    end;

    Log('Odosielam ' + DocumentId + ' -> ' + edtReceiverId.Text + '...');
    try
      ProviderDocId := Client.SendInvoice(DocumentId, DOC_TYPE_ID, PROCESS_ID,
        edtParticipantId.Text, edtReceiverId.Text, XML);
      Log('ODOSLANE. providerDocumentId = ' + ProviderDocId);
    except
      on E: Exception do
        Log('ODOSLANIE ZLYHALO: ' + E.Message);
    end;
  finally
    Client.Free;
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

  try
    Log('Kontrolujem inbox pre ' + edtParticipantId.Text + '...');
    try
      FInboxItems := Client.ListReceived('RECEIVED', 100);
      RefreshInboxList;
      Log('Najdenych ' + IntToStr(Length(FInboxItems.Documents)) + ' dokumentov.');
    except
      on E: Exception do
        Log('CHYBA: ' + E.Message);
    end;
  finally
    Client.Free;
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

  try
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
  finally
    Client.Free;
  end;
end;

procedure TFormMain.btnAcknowledgeSelectedClick(Sender: TObject);
var
  Client: TEpostakClient;
  DocId: string;
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

  try
    Log('Potvrdzujem ' + DocId + '...');
    try
      Client.AcknowledgeDocument(DocId);
      Log('OZNACENE ako ACKNOWLEDGED.');
      btnCheckInboxClick(nil);
    except
      on E: Exception do
        Log('CHYBA: ' + E.Message);
    end;
  finally
    Client.Free;
  end;
end;

end.
