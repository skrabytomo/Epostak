# Retarget Main.pas -> epostak.sk SAPI-SK

No `.dfm` changes needed. Existing fields are reused with new meaning:

| Field | Old meaning | New meaning |
|---|---|---|
| `edtBaseURL` | epodatelna24 base URL | `https://dev.epostak.sk/sapi/v1` |
| `edtToken` | API token | **your own Peppol Participant Id** (e.g. `0245:0000000001`) |
| `cmbSimulation` | epodatelna24 simulation modes | unused now, leave it, don't call `SetSimulation` |
| `btnValidate` | calls `/outbox/documents/validate` | repoint to `Authenticate` as a connectivity check (SAPI validates on send, no separate endpoint) |

## 1. uses clause

```pascal
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls, IniFiles, FileCtrl,
  EpostakClient, EpostakDemoCreds;   // <-- replaces Ep24Client
```

## 2. Field type

```pascal
private
  FClient: TEpostakClient;              // <-- was TEp24Client
  FInboxItems: TEpostakDocumentList;    // <-- was TEp24InboxList
```

## 3. Helper to build a client from the form (add this, use everywhere `TEp24Client.Create` was called)

```pascal
function TFormMain.MakeClient: TEpostakClient;
var
  ClientId, ClientSecret: string;
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigFileName);
  try
    ClientId := Ini.ReadString('EP24', 'ClientId', '');
    ClientSecret := Ini.ReadString('EP24', 'ClientSecret', '');
  finally
    Ini.Free;
  end;

  if (ClientId = '') or (ClientSecret = '') then
    if not ResolveDemoCredentials(edtToken.Text, ClientId, ClientSecret) then
      raise Exception.Create('Neznamy Participant Id: ' + edtToken.Text +
        ' - vyplnte ClientId/ClientSecret v .ini alebo pouzite demo ID.');

  Result := TEpostakClient.Create(edtBaseURL.Text, ClientId, ClientSecret, edtToken.Text);
end;
```

## 4. btnSendClick

```pascal
procedure TFormMain.btnSendClick(Sender: TObject);
var
  XML, ReceiverId, ProviderDocId, DocId: string;
  Ini: TIniFile;
begin
  if FClient <> nil then FClient.Free;
  FClient := MakeClient;

  XML := LoadXMLFromFile(edtXMLFile.Text);
  if XML = '' then
  begin
    Log('CHYBA: Najprv nacitajte XML subor.');
    Exit;
  end;

  Ini := TIniFile.Create(ConfigFileName);
  try
    ReceiverId := Ini.ReadString('EP24', 'ReceiverParticipantId', '');
  finally
    Ini.Free;
  end;
  if ReceiverId = '' then
    ReceiverId := AutoPairParticipant(edtToken.Text);
  if ReceiverId = '' then
  begin
    Log('CHYBA: Neznamy prijemca - vyplnte ReceiverParticipantId v .ini.');
    Exit;
  end;

  DocId := 'FA-' + FormatDateTime('yyyymmdd-hhnnss', Now);

  Log('Odosielam fakturu ' + DocId + ' -> ' + ReceiverId + '...');
  try
    ProviderDocId := FClient.SendInvoice(DocId,
      'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1',
      'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
      edtToken.Text, ReceiverId, XML);
    Log('ODOSLANE. providerDocumentId = ' + ProviderDocId);
  except
    on E: Exception do
      Log('ODOSLANIE ZLYHALO: ' + E.Message);
  end;
end;
```

Note: `metadata.documentTypeId` / `processId` above are constants from the
SAPI docs (Peppol BIS 3.0 Invoice billing process) - only change these if
you send a different document type (e.g. CreditNote).

## 5. btnCheckInboxClick (replaces the whole path-probing block)

```pascal
procedure TFormMain.btnCheckInboxClick(Sender: TObject);
begin
  if FClient <> nil then FClient.Free;
  FClient := MakeClient;

  Log('Kontrolujem inbox pre ' + edtToken.Text + '...');
  try
    FInboxItems := FClient.ListReceived('RECEIVED', 100);
    RefreshInboxList;
    Log('Najdenych ' + IntToStr(Length(FInboxItems)) + ' dokumentov.');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;
```

`RefreshInboxList` / `SetupInboxColumns` need field name updates since
`TEpostakDocument` has different fields than `TEp24InboxItem`:

```pascal
Item.Caption := FInboxItems[i].DocumentId;
Item.SubItems.Add(FInboxItems[i].SenderParticipantId);
Item.SubItems.Add(FInboxItems[i].DocumentTypeId);
Item.SubItems.Add(FInboxItems[i].CreationDateTime);
```
(drop the `SenderName` / `Subject` / `IsRead` columns - SAPI's list
endpoint doesn't return those, only the metadata shown above)

## 6. DownloadDocument / btnDownloadSelectedClick

```pascal
procedure TFormMain.DownloadDocument(const ADocID, ASavePath: string);
var
  XML: string;
begin
  if ADocID = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument z inboxu.');
    Exit;
  end;
  if FClient = nil then FClient := MakeClient;

  Log('Stahujem XML pre ' + ADocID + '...');
  try
    XML := FClient.GetDocumentXML(ADocID);
    EpostakClient.SaveRawBytesToFile(ASavePath, XML); // raw UTF-8 bytes, no re-encoding
    Log('ULOZENE: ' + ASavePath + ' (' + IntToStr(Length(XML)) + ' bajtov)');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;
```

## 7. btnMarkReadClick -> Acknowledge

```pascal
procedure TFormMain.btnMarkReadClick(Sender: TObject);
var
  DocID: string;
begin
  DocID := GetSelectedDocID;
  if DocID = '' then
  begin
    Log('CHYBA: Najprv vyberte dokument.');
    Exit;
  end;
  if FClient = nil then FClient := MakeClient;

  Log('Potvrdzujem ' + DocID + '...');
  try
    FClient.AcknowledgeDocument(DocID);
    Log('OZNACENE ako ACKNOWLEDGED.');
    btnCheckInboxClick(nil);
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;
```

## 8. btnValidateClick - repoint to a connectivity check

```pascal
procedure TFormMain.btnValidateClick(Sender: TObject);
begin
  if FClient <> nil then FClient.Free;
  FClient := MakeClient;
  Log('SAPI nema samostatny /validate endpoint - validacia prebieha pri /document/send.');
  Log('Testujem auth...');
  try
    FClient.Authenticate;
    Log('OK - token ziskany, spojenie funguje.');
  except
    on E: Exception do
      Log('CHYBA: ' + E.Message);
  end;
end;
```

## 9. btnGenerateKeyClick

Leave as informational-only, or delete - `SendInvoice` generates its own
`Idempotency-Key` internally on every call (required per SAPI spec,
one key per attempt). The old manual `edtIdempotencyKey` field is no
longer wired into the send path.

## 10. FormCreate

```pascal
procedure TFormMain.FormCreate(Sender: TObject);
begin
  edtBaseURL.Text := EpostakDemoCreds.EPOSTAK_SANDBOX_BASE_URL;
  edtToken.Text := EpostakDemoCreds.FIRM_A_ID; // default: send as Firma A
  SetupInboxColumns;
  edtSaveFolder.Text := ExtractFilePath(Application.ExeName) + 'inbox';
  if FileExists(ConfigFileName) then
    btnLoadConfigClick(nil);
end;
```

Delete the `cmbSimulation.Items.Add(...)` block in `FormCreate` - no
simulation modes on SAPI.

## What to test first

1. Compile `EpostakTest.dpr` alone (no VCL, no `.dfm` risk) - proves
   `EpostakClient.pas` compiles and the send call works end to end.
2. Fill in `FIRM_B_CLIENT_SECRET` in `EpostakDemoCreds.pas`, rerun -
   proves receive + acknowledge.
3. Only then touch `Main.pas` using the snippets above.
