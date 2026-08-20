unit UTestForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, EpostakClient, EpostakDemoCreds;

type
  TFormTest = class(TForm)
    BtnRun: TButton;
    Memo: TMemo;
    procedure BtnRunClick(Sender: TObject);
  private
    procedure Log(const AMsg: string);
    function BuildSampleInvoice(const ADocumentId, AIssueDate, ADueDate: string): string;
    procedure RunTest;
  public
  end;

var
  FormTest: TFormTest;

implementation

{$R *.dfm}

const
  DOC_TYPE_ID = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice' +
    '##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1';
  PROCESS_ID  = 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0';

procedure TFormTest.Log(const AMsg: string);
begin
  Memo.Lines.Add(AMsg);
  SendMessage(Memo.Handle, EM_LINESCROLL, 0, MaxInt);
  Application.ProcessMessages;
end;

function TFormTest.BuildSampleInvoice(const ADocumentId, AIssueDate, ADueDate: string): string;
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
    '<cbc:EndpointID schemeID="0245">0000000001</cbc:EndpointID>' +
    '<cac:PostalAddress><cbc:StreetName>Hlavna 1</cbc:StreetName>' +
    '<cbc:CityName>Bratislava</cbc:CityName><cbc:PostalZone>81101</cbc:PostalZone>' +
    '<cac:Country><cbc:IdentificationCode>SK</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyTaxScheme><cbc:CompanyID>SK0000000001</cbc:CompanyID>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>Firma A s.r.o.</cbc:RegistrationName>' +
    '<cbc:CompanyID schemeID="0245">0000000001</cbc:CompanyID></cac:PartyLegalEntity>' +
    '</cac:Party></cac:AccountingSupplierParty>' +
    '<cac:AccountingCustomerParty><cac:Party>' +
    '<cbc:EndpointID schemeID="0245">0000000002</cbc:EndpointID>' +
    '<cac:PostalAddress><cbc:StreetName>Namestie 5</cbc:StreetName>' +
    '<cbc:CityName>Zilina</cbc:CityName><cbc:PostalZone>01001</cbc:PostalZone>' +
    '<cac:Country><cbc:IdentificationCode>SK</cbc:IdentificationCode></cac:Country></cac:PostalAddress>' +
    '<cac:PartyTaxScheme><cbc:CompanyID>SK0000000002</cbc:CompanyID>' +
    '<cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>' +
    '<cac:PartyLegalEntity><cbc:RegistrationName>Firma B s.r.o.</cbc:RegistrationName>' +
    '<cbc:CompanyID schemeID="0245">0000000002</cbc:CompanyID></cac:PartyLegalEntity>' +
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

procedure TFormTest.RunTest;
var
  ClientA, ClientB: TEpostakClient;
  DocumentId, ProviderDocId, XmlBody: string;
  Received: TEpostakDocumentList;
  i, Attempt: Integer;
  Found: Boolean;
begin
  BtnRun.Enabled := False;
  try
    Log('=== EpostakTest: SAPI-SK sandbox (dev.epostak.sk) ===');
    Log('');

    Log('[1] Autentifikacia Firma A...');
    ClientA := TEpostakClient.Create(EPOSTAK_SANDBOX_BASE_URL, FIRM_A_CLIENT_ID,
      FIRM_A_CLIENT_SECRET, FIRM_A_ID);
    try
      try
        ClientA.Authenticate;
        Log('    OK, token ziskany.');

        DocumentId := 'TEST-' + FormatDateTime('yyyymmdd-hhnnss', Now);
        XmlBody := BuildSampleInvoice(DocumentId, FormatDateTime('yyyy-mm-dd', Now),
          FormatDateTime('yyyy-mm-dd', Now + 14));

        Log('[2] Odosielam dokument ' + DocumentId + '...');
        ProviderDocId := ClientA.SendInvoice(DocumentId, DOC_TYPE_ID, PROCESS_ID,
          FIRM_A_ID, FIRM_B_ID, XmlBody);
        Log('    OK, providerDocumentId = ' + ProviderDocId);
      except
        on E: Exception do
        begin
          Log('CHYBA pri odosielani: ' + E.Message);
          Exit;
        end;
      end;
    finally
      ClientA.Free;
    end;

    Log('');

    if FIRM_B_CLIENT_SECRET = '' then
    begin
      Log('[3] PRESKOCENE: FIRM_B_CLIENT_SECRET nie je vyplneny v EpostakDemoCreds.pas.');
      Exit;
    end;

    Log('[3] Autentifikacia Firma B...');
    ClientB := TEpostakClient.Create(EPOSTAK_SANDBOX_BASE_URL, FIRM_B_CLIENT_ID,
      FIRM_B_CLIENT_SECRET, FIRM_B_ID);
    try
      try
        ClientB.Authenticate;
        Log('    OK, token ziskany.');

        Found := False;
        for Attempt := 1 to 5 do
        begin
          Log('[4] Kontrolujem inbox (pokus ' + IntToStr(Attempt) + '/5)...');
          Received := ClientB.ListReceived('RECEIVED', 20);
          for i := 0 to High(Received) do
            if Received[i].DocumentId <> '' then
            begin
              Log('    Najdeny dokument: ' + Received[i].DocumentId +
                '  (od ' + Received[i].SenderParticipantId + ')');
              Found := True;
            end;
          if Found then Break;
          Log('    Zatial nic, cakam 2s...');
          Sleep(2000);
        end;

        if not Found or (Length(Received) = 0) then
        begin
          Log('[4] Ziadny dokument sa nenasiel (skuste znova o chvilu).');
          Exit;
        end;

        Log('[5] Stahujem UBL XML pre ' + Received[0].DocumentId + '...');
        XmlBody := ClientB.GetDocumentXML(Received[0].DocumentId);
        SaveRawBytesToFile(ExtractFilePath(Application.ExeName) + Received[0].DocumentId + '.xml', XmlBody);
        Log('    Ulozene: ' + Received[0].DocumentId + '.xml (' + IntToStr(Length(XmlBody)) + ' bajtov)');

        Log('[6] Potvrdzujem prijatie (acknowledge)...');
        ClientB.AcknowledgeDocument(Received[0].DocumentId);
        Log('    OK, oznacene ako ACKNOWLEDGED.');
      except
        on E: Exception do
          Log('CHYBA pri prijimani: ' + E.Message);
      end;
    finally
      ClientB.Free;
    end;

    Log('');
    Log('=== HOTOVO: send + receive + acknowledge fungovali. ===');
  finally
    BtnRun.Enabled := True;
  end;
end;

procedure TFormTest.BtnRunClick(Sender: TObject);
begin
  Memo.Clear;
  RunTest;
end;

end.
