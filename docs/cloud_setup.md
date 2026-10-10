# Kvaltík Notepad 1.2 — zprovoznění synchronizace

Zdrojová aplikace zůstává soukromá; veřejný repozitář je pouze pro vydané instalátory.

## 1. Vytvoř zabezpečenou tabulku poznámek

V Supabase projektu otevři **SQL Editor → New query**.
Zkopíruj CELÝ soubor [supabase/schema.sql](../supabase/schema.sql) a spusť **Run**.
Potom v **Table Editor** ověř, že existuje tabulka `public.notes` a že má **RLS enabled**.
**Nikdy nevypínej Row Level Security (RLS)**: každý uživatel musí vidět výhradně vlastní poznámky.

## 2. Ověř přihlašování e-mailem

V **Authentication → Sign In / Providers → Email** ponech povolené přihlášení e-mailem.
Doporučujeme zapnuté potvrzování e-mailu (**Confirm email**). Pokud je aktivní, nový uživatel dostane e-mail a musí účet potvrdit; potom v aplikaci klikne na **Přihlásit se**.
Není potřeba přihlašování přes Google, service_role klíč ani vlastní backend server.

## 3. Cloud připojení v sestavení

**Projekt už je propojený.** GitHub Actions v soukromém repozitáři má nastavené
URL projektu a jeho **veřejný Supabase publishable key**. Klíč je určený
pro distribuci do klientských aplikací; samotná oprávnění v databázi
vynucuje přihlášení uživatele a Row Level Security (RLS).

**Nemusíš zadávat další GitHub Secrets pro Supabase.** Pokud v budoucnu
dojde k výměně klientského klíče, lze přepsat veřejnou konfiguraci
volitelnými Actions Secrets `SUPABASE_URL` a `SUPABASE_ANON_KEY`.

**Nikdy sem nevkládej** `service_role`, `sb_secret_...`, heslo
k databázi nebo osobní přístupový token.

## 4. Test obou platforem

Po uložení SQL a GitHub secrets znovu spusť `Build Android APK and Windows` z GitHub **Actions → Run workflow**.
Při prvním testu nech `publish_release = false`. Stáhni obě testovací sestavení z Actions Artifacts a ověř:
1. Registrace nového cloudového účtu (e-mail + heslo).
2. Přihlášení STEJNÝM cloudovým účtem na obou zařízeních.
3. Poznámka vytvořená na PC se po chvíli ukáže na mobilu (nebo stiskni ikonu cloudu).
4. Offline úprava zůstane viditelná lokálně a po znovupřipojení se odešle.
5. Smazání poznámky se přenese také na druhé zařízení.

Aplikace kontroluje cloud přibližně každých 20 sekund, při návratu do aplikace a po úpravě poznámky. **Nepracuje na pozadí, pokud je úplně zavřená.**

## 5. Převod starých místních poznámek — bez jejich mazání

DŮLEŽITÉ: Nový cloudový účet je **e-mail + heslo**, nikoli staré místní jméno.
Na zařízení, kde už poznámky existují:

1. Na přihlašovací obrazovce zvol **Mám starý místní účet – převést poznámky**.
2. Přihlas se svým původním **místním uživatelským jménem a heslem**.
3. V seznamu poznámek klikni na ikonu **cloud upload**.
4. Přihlas se nebo se registruj pomocí nového cloudového e-mailu a hesla.
5. Poznámky se vloží do lokální fronty, odkud se po připojení odešlou do cloudu.
6. Na druhém zařízení se přihlas **STEJNÝM cloudovým účtem**.

Původní data `notes:uživatelské_jméno` v zařízení ponecháváme beze změny. Import se pro daný cloudový účet a místní uživatelské jméno označí jako dokončený, aby nevznikaly opakované kopie.

**POZOR:** Pokud původní APK mělo jiný podpisový klíč, Android může vyžadovat odinstalaci a tím smaže lokální poznámky. **Nepřeinstalovávej starou aplikaci dřív, než je migrováno nebo zálohováno!** Tato verze zatím nemá samostatný export do souboru.

## Omezení a bezpečnost

- Ukládání poznámek v lokální cache je zatím v `shared_preferences` (nešifrované). Neukládej sem citlivá hesla či jiné tajné údaje.
- V cloudu chrání řádky RLS a ověřená uživatelská identita.
- Konfliktní současné úpravy **stejné poznámky** na dvou zařízeních nejsou plně vyřešené; platí poslední úspěšně zapsaná změna na serveru.
- Úpravy bez internetu jsou frontované na zařízení; při odhlášení nebo smazání dat aplikace se neodeslané změny mohou ztratit.
- Synchronizace spuštěná při otevřené aplikaci není totéž co trvalá synchronizace na pozadí.
