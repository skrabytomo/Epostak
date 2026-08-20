# Epostak SAPI-SK — Kompletný návod

> **Verzia:** 1.0  
> **Dátum:** 2026-08-20  
> **Jazyk:** Slovenčina  
> **Cieľová skupina:** Delphi vývojári integrujúci ePošťák (Peppol Access Point)

---

## 1. Čo je toto?

Tento repozitár obsahuje **Delphi knižnicu a aplikáciu** pre komunikáciu so slovenským Peppol Access Pointom [ePošťák](https://epostak.sk) cez štandardizované API **SAPI-SK**.

### Čo dokáže:
- Odosielať elektronické faktúry (Peppol BIS 3.0 UBL XML)
- Prijímať faktúry do inboxu
- Sťahovať prijaté UBL XML dokumenty
- Potvrdzovať (acknowledge) prijaté dokumenty
- Spravovať OAuth tokeny (autentifikácia, obnova, revokácia)

### Čo nepotrebujete:
- Žiadne externé DLL ani komponenty
- Žiadny .NET runtime
- Iba Delphi 6+ a WinInet (súčasť Windows)

---

## 2. Prehľad súborov

| Súbor | Popis | Čo s ním robiť |
|-------|-------|-----------------|
| `EpostakClient.pas` | **Jadro knižnice** — všetky API volania | Skopírujte do vášho projektu |
| `EpostakDemoCreds.pas` | Demo prihlasovacie údaje pre sandbox | Použite na test, v produkcii nahraďte |
| `EpostakApp.dpr` | Ukážková GUI aplikácia | Preložte, spustite, pozrite ako to funguje |
| `UMainForm.pas` / `.dfm` | Formulár GUI aplikácie | Šablóna pre vašu vlastnú aplikáciu |
| `INTEGRATION.md` | Migrácia z epodatelna24 | Ak ste používali staré API |
| `sample-invoice*.xml` | Vzorové UBL XML faktúry | Testovacie dáta |

---

## 3. Rýchly štart — Sandbox (5 minút)

### Krok 1: Preložte a spustite
```
Delphi → Otvoriť projekt → EpostakApp.dpr → Run
```

### Krok 2: Kliknite "Demo: Firma A (send)"
Toto vyplní:
- Base URL: `https://dev.epostak.sk/sapi/v1`
- ClientId / ClientSecret pre demo Firmu A
- ParticipantId: `0245:0000000001`

### Krok 3: Kliknite "ODOSLAT"
Odošle testovaciu faktúru z Firmy A na Firmu B.

### Krok 4: Kliknite "Demo: Firma B (recv)"
Prepnite na prijímateľa (Firma B).

### Krok 5: Kliknite "Skontrolovat inbox"
Mali by ste vidieť prijatú faktúru. Kliknite na ňu → "Stiahnut vybrany" → "Potvrdit vsetky vybrate".

**Hotovo.** Celý cyklus funguje.

---

## 4. Recept na prechod do produkcie (Sandbox → Live)

> ⚠️ **DÔLEŽITÉ:** Postupujte krok za krokom. Nepreskakujte overovacie kroky.

### Fáza 1: Príprava (pred prvým live volaním)

#### 1.1 Získajte produkčné credentialy
Na [epostak.sk](https://epostak.sk) si vytvorte účet alebo kontaktujte podporu:
```
Potrebujete:
  ✓ Peppol Participant ID (napr. 0245:1234567890)
  ✓ Client ID
  ✓ Client Secret
  ✓ Zmluvu o pripojení k Peppol
```

#### 1.2 Zmeňte Base URL
V kóde alebo v `.ini` konfigurácii zmeňte:
```pascal
// Sandbox (testovanie)
FBaseURL := 'https://dev.epostak.sk/sapi/v1';

// Produkcia (skutočné faktúry)
FBaseURL := 'https://api.epostak.sk/sapi/v1';
```

#### 1.3 Nahraďte demo credentialy
V súbore `EpostakDemoCreds.pas` alebo vo vašej konfigurácii:
```pascal
// ZMAŽTE alebo zakomentujte demo údaje
// FIRM_A_CLIENT_ID = '487d008a-...';

// POUŽITE vlastné
FClientId     := 'vas-produkcny-client-id';
FClientSecret := 'vas-produkcny-client-secret';
FParticipantId := '0245:vas-dic';
```

#### 1.4 Zabezpečte Client Secret
> 🔒 **Client Secret = heslo k vášmu účtu. Nikdy ho neukladajte do zdrojového kódu v plain texte.**

**Odporúčané riešenia pre Delphi:**

**A) Windows Credential Manager (najbezpečnejšie)**
```pascal
uses Windows, WinCred;

// Uloženie
CredWriteGeneric('EpostakClientSecret', 'vas-tajny-kluc');

// Načítanie
FClientSecret := CredReadGeneric('EpostakClientSecret');
```

**B) Zašifrovaný INI súbor**
```pascal
uses EpostakClientUtils; // pridajte si pomocnú unitu

// Pred uložením zašifrujte
Ini.WriteString('EPOSTAK', 'ClientSecret', 
  EncryptString(FClientSecret, 'vas-lokalny-heslo'));

// Pri načítaní dešifrujte
FClientSecret := DecryptString(
  Ini.ReadString('EPOSTAK', 'ClientSecret', ''), 
  'vas-lokalny-heslo');
```

**C) Aspoň .ini mimo git**
```gitignore
# Do .gitignore pridajte:
*.ini
config/
secrets/
```

### Fáza 2: Overenie pred produkciou

#### 2.1 Otestujte autentifikáciu
```pascal
var
  Client: TEpostakClient;
begin
  Client := TEpostakClient.Create(
    'https://api.epostak.sk/sapi/v1',
    'vas-client-id',
    'vas-client-secret',
    '0245:vas-dic'
  );
  try
    Client.Authenticate;
    if Client.TokenStatus then
      ShowMessage('Autentifikácia OK — token je platný');
  finally
    Client.Free;
  end;
end;
```

#### 2.2 Odošlite testovaciu faktúru sebe
Najprv odošlite faktúru z **vlastného** Participant ID na **vlastné** Participant ID (ak to ePošťák podporuje) alebo na známy testovací endpoint.

#### 2.3 Overte schému UBL XML
```
Váš UBL XML musí spĺňať:
  ✓ Peppol BIS 3.0 špecifikáciu
  ✓ EN16931 (european norm)
  ✓ Slovenské špecifické pravidlá (ISDOC kompatibilita)

Overenie online:
  https://peppol.helger.com/public/menuitem-validation-bis3
```

#### 2.4 Skontrolujte časové zóny
```pascal
// Uistite sa, že server má správny čas
// creationDateTime musí byť UTC
// Knižnica to robí automaticky cez GetSystemTime,
// ale overte na testovacej faktúre.
```

### Fáza 3: Go-live checklist

```
□ Zmenené BaseURL na produkciu
□ Nahradené demo credentialy za vlastné
□ ClientSecret nie v plain texte v zdrojáku
□ UBL XML validované cez Peppol validator
□ Odoslaná testovacia faktúra
□ Prijatá testovacia faktúra
□ Potvrdená (acknowledge) testovacia faktúra
□ Nastavené automatické mazanie / archivovanie inboxu
□ Logovanie zapnuté pre audit
□ Rate-limity otestované (max 100 volaní/min)
□ Error handling otestované (vypnutý internet, zlý token...)
```

---

## 5. Ako integrovať do existujúcej Delphi aplikácie

### Scenár A: Jednoduchá integrácia (1-2 dni)

**Cieľ:** Pridať tlačidlo "Odoslať elektronicky" do existujúceho formulára faktúr.

**Postup:**

1. **Pridajte `EpostakClient.pas` do projektu**
   ```
   Project → Add to Project → EpostakClient.pas
   ```

2. **Vytvorte konfiguračný formulár**
   ```pascal
   // Nový formulár: TfrmEpostakConfig
   // Polia: BaseURL, ClientId, ClientSecret, ParticipantId
   // Tlačidlo: "Test pripojenia" → volá Client.TokenStatus
   ```

3. **Do formulára faktúry pridajte:**
   ```pascal
   uses EpostakClient;

   procedure TfrmFaktura.btnOdoslatElektronickyClick(Sender: TObject);
   var
     Client: TEpostakClient;
     UblXml: string;
   begin
     // 1. Načítajte konfiguráciu
     Client := TEpostakClient.Create(
       ReadConfig('EpostakBaseURL'),
       ReadConfig('EpostakClientId'),
       ReadConfig('EpostakClientSecret'),
       ReadConfig('EpostakParticipantId')
     );

     try
       // 2. Vygenerujte UBL XML z vašich dát
       UblXml := GenerujUBLXmlZFaktury(FFaktura);

       // 3. Odošlite
       Client.SendInvoice(
         FFaktura.Cislo,
         'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice' +
           '##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1',
         'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
         ReadConfig('EpostakParticipantId'),
         FFaktura.OdberatelPeppolId,  // z databázy
         UblXml
       );

       ShowMessage('Faktúra odoslaná cez Peppol.');
       FFaktura.Stav := fsOdoslane;
       FFaktura.Save;
     finally
       Client.Free;
     end;
   end;
   ```

4. **Generovanie UBL XML z vašich dát**
   ```pascal
   function GenerujUBLXmlZFaktury(AFaktura: TFaktura): string;
   begin
     // Použite šablónu (string literal) a nahraďte placeholdre
     Result := LoadTemplate('ubl_invoice_template.xml');
     Result := StringReplace(Result, '{ID}', AFaktura.Cislo, [rfReplaceAll]);
     Result := StringReplace(Result, '{IssueDate}', FormatDateTime('yyyy-mm-dd', AFaktura.Datum), [rfReplaceAll]);
     Result := StringReplace(Result, '{DueDate}', FormatDateTime('yyyy-mm-dd', AFaktura.DatumSplatnosti), [rfReplaceAll]);
     // ... ďalšie polia
   end;
   ```

### Scenár B: Plná integrácia s inboxom (3-5 dní)

**Cieľ:** Pridať do ERP modul "Elektronická pošta" s inboxom a outboxom.

**Architektúra:**
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Váš ERP systém │────▶│ EpostakClient   │────▶│  ePošťák API    │
│                 │     │ (táto knižnica) │     │  (Peppol AP)    │
│  • Fakturácia   │◀────│                 │◀────│                 │
│  • Inbox/Outbox │     └─────────────────┘     └─────────────────┘
│  • Archív       │
└─────────────────┘
```

**Databázová štruktúra (odporúčaná):**
```sql
CREATE TABLE EPO_DOC_OUTBOX (
  ID INTEGER PRIMARY KEY,
  DOKUMENT_ID VARCHAR(255),        -- číslo faktúry
  PROVIDER_DOC_ID VARCHAR(255),     -- čo vráti API
  STATUS VARCHAR(20),              -- PENDING, SENT, ERROR
  XML_DATA BLOB,                    -- odoslané UBL XML
  CREATED_AT TIMESTAMP,
  SENT_AT TIMESTAMP,
  ERROR_MSG VARCHAR(500)
);

CREATE TABLE EPO_DOC_INBOX (
  ID INTEGER PRIMARY KEY,
  DOCUMENT_ID VARCHAR(255),        -- ID z Peppol
  SENDER_ID VARCHAR(50),            -- kto poslal
  DOCUMENT_TYPE VARCHAR(50),        -- Invoice, CreditNote...
  XML_DATA BLOB,                    -- prijaté UBL XML
  STATUS VARCHAR(20),              -- RECEIVED, ACKNOWLEDGED, IMPORTED
  RECEIVED_AT TIMESTAMP,
  ACKNOWLEDGED_AT TIMESTAMP
);
```

**Background sync (timer alebo thread):**
```pascal
procedure TfrmMain.tmSyncTimer(Sender: TObject);
var
  Client: TEpostakClient;
  Received: TEpostakDocumentListResult;
  i: Integer;
begin
  Client := TEpostakClient.Create(...);
  try
    // 1. Skontroluj inbox
    Received := Client.ListReceived('RECEIVED', 100);

    // 2. Ulož nové do databázy
    for i := 0 to High(Received.Documents) do
      if not ExistsInDatabase(Received.Documents[i].DocumentId) then
        ImportToInbox(Received.Documents[i], Client.GetDocumentXML(...));

    // 3. Potvrď všetky nové
    for i := 0 to High(Received.Documents) do
      Client.AcknowledgeDocument(Received.Documents[i].DocumentId);

  finally
    Client.Free;
  end;
end;
```

### Scenár C: Headless server (Windows service)

**Cieľ:** Automatické odosielanie faktúr bez GUI.

```pascal
// Windows Service alebo konzolová aplikácia
program EpostakSyncService;

{$APPTYPE CONSOLE}

uses
  SysUtils, EpostakClient, DB; // vaša DB unita

procedure SyncOutbox;
var
  Client: TEpostakClient;
  Q: TQuery;
begin
  Client := TEpostakClient.Create(...);
  try
    Q := TQuery.Create(nil);
    try
      Q.SQL.Text := 'SELECT * FROM EPO_DOC_OUTBOX WHERE STATUS = ''PENDING''';
      Q.Open;
      while not Q.Eof do
      begin
        try
          Client.SendInvoice(
            Q.FieldByName('DOKUMENT_ID').AsString,
            DOC_TYPE_ID, PROCESS_ID,
            ParticipantId,
            Q.FieldByName('RECEIVER_ID').AsString,
            Q.FieldByName('XML_DATA').AsString
          );
          Q.Edit;
          Q.FieldByName('STATUS').AsString := 'SENT';
          Q.FieldByName('SENT_AT').AsDateTime := Now;
          Q.Post;
        except
          on E: Exception do
          begin
            Q.Edit;
            Q.FieldByName('STATUS').AsString := 'ERROR';
            Q.FieldByName('ERROR_MSG').AsString := E.Message;
            Q.Post;
          end;
        end;
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  finally
    Client.Free;
  end;
end;

begin
  while True do
  begin
    SyncOutbox;
    SyncInbox;
    Sleep(60000); // každú minútu
  end;
end.
```

---

## 6. Bezpečnosť a best practices

### Token management
```pascal
// Knižnica to robí automaticky, ale vedzte:
// • access_token platí 15 minút (cachuje sa)
// • refresh_token platí 30 dní
// • Pri 401 sa automaticky volá RenewToken
// • Pred odhlásením zavolajte Client.RevokeToken
```

### Rate limity
```
Maximálne 100 volaní za minútu na token.
Knižnica má built-in retry pre 429 (rate limit) s exponenciálnym backoffom.
Ak potrebujete viac — kontaktujte ePošťák.
```

### Audit a logovanie
```pascal
// Logujte všetky API volania pre účely auditu
procedure LogApiCall(const AMethod, AEndpoint, ARequestId: string);
begin
  // Uložte do databázy alebo súboru
  // RequestId získate z chybovej odpovede alebo si ho generujte
end;
```

### WORM archív
```
ePošťák archivuje všetky dokumenty 10 rokov (WORM).
Vy si ale musíte uchovávať vlastnú kópiu pre rýchly prístup.
Odporúčané: uložiť XML do databázy hneď po odoslaní/prijatí.
```

---

## 7. Troubleshooting

| Problém | Príčina | Riešenie |
|---------|---------|----------|
| `HTTP 401` | Token expirovaný | Knižnica automaticky obnoví, ak nie — zavolaj `Authenticate` |
| `HTTP 409` | Idempotency key kolízia | Knižnica retryuje automaticky, počkajte chvíľu |
| `HTTP 422` | UBL XML nie je validné | Skontrolujte cez Peppol validator, upravte XML |
| `HTTP 429` | Rate limit | Počkajte minútu, optimalizujte počet volaní |
| `HTTP 503` | Dočasná nedostupnosť | Knižnica retryuje, skúste neskôr |
| `SSL error` | WinInet / certifikát | Aktualizujte Windows, skontrolujte proxy |
| `Token sa neobnoví` | Refresh token expirovaný | Zavolajte `Authenticate` namiesto `RenewToken` |

---

## 8. Časté otázky

**Q: Môžem používať túto knižnicu v komerčnom projekte?**  
A: Áno, ale potrebujete vlastný účet na ePošťák. Demo credentialy sú len na test.

**Q: Funguje to s Delphi 5?**  
A: Nie, používame `TDateTime` operácie a `Int64` ktoré Delphi 5 nemá. Minimum je Delphi 6.

**Q: Ako často kontrolovať inbox?**  
A: Pre desktop appku — pri štarte a na požiadanie. Pre service — každých 5-15 minút.

**Q: Čo ak prijmem faktúru a nepotvrdím ju?**  
A: Zostane v stave RECEIVED. ePošťák ju bude ponúkať pri každom `ListReceived` volaní.

**Q: Môžem zmazať odoslanú faktúru?**  
A: Nie, WORM archív ju drží 10 rokov. Ale môžete ju označiť ako stornovanú (CreditNote).

---

## 9. Kontakty a podpora

- **Dokumentácia API:** https://epostak.sk/api/docs  
- **Podpora ePošťák:** podpora@epostak.sk  
- **Peppol validátor:** https://peppol.helger.com  
- **EN16931 špecifikácia:** https://ec.europa.eu/cefdigital/wiki/display/CEFDIGITAL/EN+16931

---

*Posledná aktualizácia: 2026-08-20*  
*Autor: skrabytomo*  
*Licencia: Použitie na vlastné riziko, pre produkciu kontaktujte ePošťák*
