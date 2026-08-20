# Epostak — SAPI-SK Delphi Client

> Delphi 6+ klient pre [ePošťák](https://epostak.sk) SAPI-SK API — slovenský Peppol Access Point.

## Čo to je

`EpostakClient.pas` je minimálna knižnica na odosielanie a prijímanie Peppol BIS 3.0 UBL faktúr cez SAPI-SK štandard. Používa len WinInet — žiadne externé DLL, žiadne závislosti. Kompatibilné s Delphi 6.

## Rýchly štart

1. **Sandbox test** — spusti konzolový test:
   ```bash
   # Prelož a spusť EpostakTest.dpr
   # Automaticky odošle faktúru z Firmy A na Firmu B
   ```

2. **GUI test** — spusti vizuálny test:
   ```bash
   # Prelož a spusť EpostakTestGUI.dpr
   # Tlačidlo "Spusti test" v okne
   ```

3. **Integrácia do vlastného ERP** — pozri `INTEGRATION.md` (migrácia z epodatelna24) alebo použij priamo `EpostakClient`:
   ```pascal
   var
     Client: TEpostakClient;
   begin
     Client := TEpostakClient.Create(
       'https://dev.epostak.sk/sapi/v1',
       'tvoj-client-id',
       'tvoj-client-secret',
       '0245:0000000001'  // Peppol ID
     );
     Client.SendInvoice(...);
   end;
   ```

## Súbory

| Súbor | Popis |
|-------|-------|
| `EpostakClient.pas` | Core knižnica — auth, send, receive, acknowledge, retry, pagination |
| `EpostakDemoCreds.pas` | Verejné demo credentialy pre sandbox (Firma A / Firma B) |
| `EpostakTest.dpr` | Konzolový end-to-end test (auth → send → receive → ack) |
| `EpostakTestGUI.dpr` | GUI verzia testu — okno s logom |
| `EpostakApp.dpr` / `UMainForm.pas` | Plná GUI aplikácia na odosielanie / inbox |
| `INTEGRATION.md` | Sprievodca migráciou z epodatelna24 API |
| `SAPI_REVIEW.md` | Detailný review implementácie vs. SAPI-SK špecifikácia |
| `sample-invoice.xml` | Vzorová Peppol BIS 3.0 faktúra (1 položka, 114 EUR) |
| `sample-invoice-multi-item.xml` | Faktúra s 3 položkami (684 EUR) |
| `sample-invoice-credit-note.xml` | Dobropis / Credit Note (typ 381, záporné sumy) |
| `sample-invoice-minimal.xml` | Minimálna validná faktúra (120 EUR) |
| `sample-invoice-czk.xml` | Faktúra v CZK mene (25200 CZK) |

## Endpointy (8 štandardných)

| Metóda | Endpoint | Popis |
|--------|----------|-------|
| POST | `/auth/token` | OAuth client_credentials |
| POST | `/auth/renew` | Refresh token rotation |
| POST | `/auth/revoke` | Revoke token |
| GET | `/auth/token/status` | Health check |
| POST | `/document/send` | Odoslanie UBL XML |
| GET | `/document/receive` | Zoznam prijatých (s pagination) |
| GET | `/document/receive/{id}` | Detail + UBL XML payload |
| POST | `/document/receive/{id}/acknowledge` | Potvrdenie spracovania |

## Bezpečnosť

- `client_secret` nikdy necommituj do gitu
- V produkcii nepoužívaj `EpostakDemoCreds` — použij vlastné credentialy
- Token sa cachuje 14 minút, refresh token 30 dní
- `RevokeToken` zavolaj pri odhlásení / incidente

## Build

- Delphi 6 alebo novší
- Žiadne externé balíky — len VCL + WinInet
- Prelož `.dpr`, spusť `.exe`

## Licencia

Bez explicitnej licencie — použitie na vlastné riziko. Pre produkciu kontaktuj [ePošťák](https://epostak.sk).
