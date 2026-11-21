# Kontrola OM – iOS aplikace (instalace bokem, bez App Store)

Nativní iOS aplikace (Swift/SwiftUI) s přibalenou kontrolní logikou. Funguje plně offline,
historie kontrol se ukládá v telefonu, protokol jde sdílet přes systémové menu (WhatsApp, e-mail, Poznámky).

## Jak se sestaví
Mac není potřeba. Po každém nahrání do větve `main` sestaví GitHub Actions (macOS) soubor
`KontrolaOM.ipa` (nepodepsaný). Stáhnete ho v repozitáři: **Actions → poslední běh „Sestavit IPA“ → Artifacts → KontrolaOM-ipa** (zip, uvnitř .ipa).

## Instalace do iPhonu z Windows (Sideloadly, zdarma)
1. Nainstalujte **iTunes** a **iCloud** z webu Apple (ne verze z Microsoft Store).
2. Stáhněte **Sideloadly** ze sideloadly.io a nainstalujte.
3. Připojte iPhone kabelem, odemkněte ho a potvrďte „Důvěřovat tomuto počítači“.
4. V Sideloadly přetáhněte `KontrolaOM.ipa`, zadejte své Apple ID a klikněte **Start**.
   (Sideloadly aplikaci podepíše vaším Apple ID.)
5. V iPhonu: **Nastavení → Obecné → Správa VPN a zařízení** → svůj Apple ID → **Důvěřovat**.
6. iOS 16 a novější: **Nastavení → Soukromí a zabezpečení → Režim pro vývojáře** → zapnout, restart.

## Omezení bezplatného Apple ID
- Podpis platí **7 dní**. Pak aplikaci znovu nahrajte přes Sideloadly (data v aplikaci zůstanou),
  nebo zapněte v Sideloadly automatické obnovování (počítač a telefon ve stejné Wi-Fi).
- Max. 3 takto nahrané aplikace současně.
- S placeným účtem Apple Developer (99 USD/rok) podpis platí 1 rok.

## Struktura
- `project.yml` – definice projektu pro XcodeGen
- `KontrolaOM/KontrolaOMApp.swift` – nativní obal aplikace
- `KontrolaOM/Web/index.html` – kontrolní logika a obrazovky
- `.github/workflows/build-ipa.yml` – automatické sestavení .ipa
