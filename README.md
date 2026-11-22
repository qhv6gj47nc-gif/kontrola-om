# Kontrola OM – iOS aplikace (instalace bokem, bez App Store)

Nativní iOS aplikace (Swift/SwiftUI) s přibalenou kontrolní logikou. Funguje plně offline,
historie kontrol se ukládá v telefonu, protokol jde sdílet přes systémové menu (WhatsApp, e-mail, Poznámky).

## Jak se sestaví
Mac není potřeba. Po každém nahrání do větve `main` sestaví GitHub Actions (macOS) soubor
`KontrolaOM.ipa` (nepodepsaný) a zveřejní ho v **Releases**:
https://github.com/qhv6gj47nc-gif/kontrola-om/releases/latest/download/KontrolaOM.ipa

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

## Rozpoznávání rozváděče z fotky
Na úvodní obrazovce „Vyfotit rozváděč“ nebo „Vybrat z galerie“. Fotka se odešle k rozboru do Claude
(model `claude-opus-5-5`, Anthropic API), aplikace ukáže návrh (fáze, jistič, typ elektroměru, tarif, HDO
a předvyplněné body kontroly) a po „Použít návrh“ se předvyplněné body označí v průvodci k potvrzení.

Potřebuje internet a vlastní API klíč:
1. Na https://console.anthropic.com si založte účet, nabijte kredit a vytvořte API klíč.
2. V aplikaci: dole „Nastavení rozpoznávání“ → vložit klíč → Uložit. Klíč se uloží v klíčence iPhonu.

Cena je řádově 1–2 Kč za fotku. Pravidla rozpoznávání z praxe jsou v `index.html` ve funkci `photoRequest()`.
