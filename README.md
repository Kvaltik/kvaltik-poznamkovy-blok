# Kvaltík Notepad 📝

Poznámkový blok pro **Android a Windows**, vytvořený ve Flutteru.

## Funkce
- Načítací obrazovka
- Lokální registrace a přihlášení (účty jsou oddělené podle zařízení)
- Volba „Zapamatovat přihlášení“
- Tvorba, editace, smazání a vyhledávání poznámek
- Tmavý / světlý režim
- Lokální ukládání poznámek

> **Dosud není hotová cloudová synchronizace ani automatické aktualizace.** Data se ukládají jen v daném zařízení. Jedná se o první verzi.

## Stáhnout APK a EXE
1. Otevři záložku **Actions** v tomto repozitáři.
2. Vyber **Build Android APK and Windows**.
3. V úspěšném běhu najdeš dole sekci **Artifacts**.
4. Stáhni **KvaltikNotepad-Android-APK** nebo **KvaltikNotepad-Windows-Setup-EXE**.
5. Stažený archiv rozbal a spusť soubor .apk nebo .exe.

Pokud běh není zelený, build selhal a instalátory zatím nejsou k dispozici. Výpis chyby je v příslušné úloze.

**Při prvním spuštění zvol „Vytvořit nový účet“.** Na druhém zařízení je potřeba vytvořit samostatný lokální účet.

## Vývoj
Základem je Flutter. Workflow generuje standardní složky platformy příkazem `flutter create` a poté vytváří vydání pro Android a Windows. Windows instalátor se balí nástrojem Inno Setup.

Projekt je prototyp; pro produkční nasazení je potřeba bezpečnější úložiště uživatelských údajů a dat.
