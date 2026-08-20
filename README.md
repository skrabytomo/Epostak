# Epostak — SAPI-SK Delphi Klient

> Delphi 6+ knižnica a aplikácia pre [ePošťák](https://epostak.sk) — slovenský Peppol Access Point.

## Rýchly štart

1. **Stiahnite** repozitár
2. **Otvorte** `EpostakApp.dpr` v Delphi
3. **Kliknite** "Demo: Firma A (send)" → "ODOSLAT"
4. **Prepnite** na "Demo: Firma B (recv)" → "Skontrolovat inbox"
5. **Hotovo** — faktúra prešla celým cyklom

📖 **Kompletný návod** (prechod do produkcie, integrácia, bezpečnosť):  
👉 **[NAVOD.md](NAVOD.md)**

## Súbory

| Súbor | Popis |
|-------|-------|
| `EpostakClient.pas` | Core knižnica — auth, send, receive, acknowledge, retry, pagination |
| `EpostakDemoCreds.pas` | Demo credentialy pre sandbox (Firma A / Firma B) |
| `EpostakApp.dpr` | Hlavná GUI aplikácia — odosielanie + inbox |
| `UMainForm.pas` / `.dfm` | GUI formulár s batch acknowledge a formátovaným inboxom |
| `INTEGRATION.md` | Sprievodca migráciou zo starého epodatelna24 API |
| `NAVOD.md` | **Kompletný slovenský návod** — sandbox, produkcia, integrácia, FAQ |
| `sample-invoice*.xml` | 5 vzorových UBL XML faktúr (rôzne scenáre) |

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

- `client_secret` **nikdy** necommitujte do gitu
- V produkcii použite Windows Credential Manager alebo šifrovaný config
- Token sa cachuje 14 minút, refresh token 30 dní
- `RevokeToken` zavolajte pri odhlásení / incidente
- Rate limit: 100 volaní/minútu

## Build

- Delphi 6 alebo novší
- Žiadne externé balíky — len VCL + WinInet
- Preložte `.dpr`, spusťte `.exe`

## Podpora

- **Dokumentácia API:** https://epostak.sk/api/docs
- **Kompletný návod:** [NAVOD.md](NAVOD.md)
- **Migrácia z epodatelna24:** [INTEGRATION.md](INTEGRATION.md)

---

*Repozitár: [github.com/skrabytomo/Epostak](https://github.com/skrabytomo/Epostak)*
