# Kvaltík Notepad 📝

Poznámkový blok pro **Windows (EXE)** a **Android (APK)** vytvořený ve Flutteru.

## Co aplikace umí
- Načítací obrazovka, cloudová registrace/přihlášení (e-mail a heslo) i přístup ke starým místním účtům.
- Poznámky, automatické ukládání, vyhledávání, světlý/tmavý režim.
- Kontrola nových verzí při otevření poznámek i ručně ikonou Aktualizace.
- Pokud vyšla novější verze, dialog **Aktualizovat** / **Později** a seznam změn.
- Tlačítko Aktualizovat otevře bezpečný odkaz na instalační soubor v prohlížeči; instalaci uživatel potvrzuje.

**Novinka 1.2.0:** Offline-first synchronizace poznámek přes Supabase na PC a mobilu včetně bezpečného převodu starých místních poznámek. Vyžaduje jednorázové [nastavení Supabase](docs/cloud_setup.md) a spuštění [SQL databázového skriptu](supabase/schema.sql). Před přeinstalací Androidu původní data nejdřív převeď nebo zazálohuj.

## Synchronizace Windows ↔ Android

Propojení účtu a synchronizace funguje od verze **1.2.0**, pokud je dokončeno nastavení Supabase. Při práci bez připojení ukládá aplikace změny lokálně a posílá je po připojení. Změny se stahují v otevřené aplikaci přibližně každých 20 sekund a také po návratu do aplikace.

**Postup zprovoznění včetně dvou GitHub Secrets, RLS a převodu lokálních účtů:** [docs/cloud_setup.md](docs/cloud_setup.md).

## Architektura aktualizací

| Zdroj | Přístup | K čemu slouží |
|---|---|---|
| `Kvaltik/kvaltik-poznamkovy-blok` | **Private** | Zdrojové kódy, GitHub Actions, zabezpečené Secrets |
| `Kvaltik/kvaltik-notepad-updates` | **Public** | Pouze GitHub Releases s APK, EXE a popisem novinek |

Aplikace se ptá na nejnovější veřejné vydání přes:
`https://api.github.com/repos/Kvaltik/kvaltik-notepad-updates/releases/latest`

Veřejné vydání musí obsahovat soubory **KvaltikNotepad-Android.apk** a
**KvaltikNotepad-Setup.exe**. Běžné artefakty z Actions nejsou veřejným vydáním.

## Jednorázové nastavení (provádí vlastník repozitářů)

### 1. Vytvoř veřejný distribuční repozitář

Na GitHubu založ **Public** repozitář `Kvaltik/kvaltik-notepad-updates`.
Při zakládání zaškrtni **Add a README file**, aby měl repozitář výchozí větev `main`.
**Nekopíruj** do něj `lib/`, `android/`, `windows/` ani jiné zdrojové soubory.

### 2. Povol publikování do druhého repozitáře

V GitHubu zvol **Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
Vytvoř token omezený výhradně na **Kvaltik/kvaltik-notepad-updates** s oprávněním
**Contents: Read and write** (Metadata: Read je implicitní). Doporučuje se expirace a následná obnova tokenu.

V **SOUKROMÉM** repozitáři `Kvaltik/kvaltik-poznamkovy-blok` otevři:
**Settings → Secrets and variables → Actions → New repository secret**.
Přidej tajný údaj s přesným názvem **UPDATES_RELEASE_TOKEN** a hodnotou vygenerovaného tokenu.

**Token nikam neposílej do chatu a nikdy ho nevkládej do kódu.**

### 3. Přidej stabilní podpis Androidu

Pro aktualizace APK Android vyžaduje **stejný balíček a stejný podpisový klíč**
při každém vydání. Vývojové APK sestavené bez trvalého klíče
nelze spolehlivě aktualizovat přes další GitHub Actions běh.

V počítači s JDK v terminálu vytvoř podpisový klíč (příkaz `keytool`):
```bash
keytool -genkeypair -v -keystore KvaltikNotepad-release.jks -alias kvaltik -keyalg RSA -keysize 3072 -validity 10000
```
Zadej heslo keystore a klíče. Ulož si soubor `.jks` a hesla bezpečně
mimo GitHub; **bez tohoto souboru nelze vydávat kompatibilní aktualizace APK**.

Ve Windows PowerShellu lze vytvořit Base64 řetězec a zkopírovat jej do schránky:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path ".\KvaltikNotepad-release.jks"))) | Set-Clipboard
```

V **soukromém** repozitáři nastav tyto čtyři GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64` — Base64 obsah souboru JKS.
- `ANDROID_KEY_ALIAS` — například `kvaltik`.
- `ANDROID_KEY_PASSWORD` — heslo k podpisovému klíči.
- `ANDROID_STORE_PASSWORD` — heslo k úložišti JKS.

Workflow tyto údaje nikdy neukládá do repozitáře. Pokud chybějí,
**publikování se zastaví**, místo aby vytvořilo APK s nestabilním podpisem.

**Migrace z prototypu 1.0:** APK dříve sestavená s dočasným/debug podpisem
se nemusí dát aktualizovat na nové trvale podepsané APK. V takovém případě
může být nutné starou aplikaci odinstalovat; tím se mohou smazat lokální poznámky.
Před takovým krokem je zálohuj.

## Jak vydat novou verzi

1. V soukromém repozitáři otevři **Actions → Build Android APK and Windows → Run workflow**.
2. Nastav `release_version` (například `1.1.0`; příště `1.1.1` nebo `1.2.0`).
3. Zapni `publish_release` a vyplň `release_notes` (text zobrazený v aplikaci).
4. Workflow sestaví obě platformy a **až při úspěchu obou** zveřejní
   pouze instalační soubory do `Kvaltik/kvaltik-notepad-updates`.
5. Veřejné vydání najdeš na
   https://github.com/Kvaltik/kvaltik-notepad-updates/releases

Na běžný push do `main` se automaticky spustí **testovací sestavení obou platforem**,
ale nic veřejně nevydává. Pro vydání je potřeba spustit workflow s `publish_release=true`.
Číslo verze pro Android se odvozuje z číselného `major.minor.patch` tak,
aby bylo při každém dalším vydání vyšší.

## Co znamená tlačítko Aktualizovat

Po spuštění aplikace zjišťuje novější verzi z **veřejných GitHub Releases**.
**Později** zavře dialog až do dalšího spuštění poznámek.
**Aktualizovat** otevře odkaz na APK/EXE v externím prohlížeči.
Instalaci musí potvrdit uživatel; v této verzi nejde o tichou instalaci na pozadí.

Aktualizace se neobjeví na původní verzi **1.0**, která ještě neuměla používat
veřejný distribuční kanál. Verzi **1.1** je potřeba jednorázově nainstalovat ručně.

## Bezpečnost a známá omezení

- Soukromý zdrojový kód se do veřejných Releases nenahrává.
- GitHub Actions tajné údaje používejte pouze v soukromém repozitáři.
- Cloudová synchronizace je v kódu připravená; bez konfigurace Supabase není aktivní.
- Lokální účty v prototypu ukládají hesla pomocí shared_preferences a lokální poznámky jsou bez šifrování;
  **není to bezpečné úložiště vhodné pro citlivá data**. Před veřejným nasazením je
  potřeba posílit ověřování a šifrování.
- Finální instalátory zatím vyžadují testování na skutečném Windows a Android zařízení.
