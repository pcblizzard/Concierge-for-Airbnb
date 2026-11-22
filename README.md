# Concierge for Airbnb

Wand-Tablet (Android) für Gäste einer Airbnb-Wohnung in München. Mehrsprachig per Sprache oder Text.

## Architektur
- **Flutter** (Android-Tablet). Avalonia wird nicht gebraucht: zwei UI-Stacks doppeln nur die Arbeit.
- **`assets/wohnung.json`** wird nur auf Deutsch gepflegt und bei jeder Frage unsichtbar als Kontext an die LLM gegeben. Die LLM antwortet in der erkannten Gastsprache.
- **Update ohne neuen Build:** `WohnungRepository.remoteUrl` auf die GitHub-raw-URL der Datei setzen; Asset ist Offline-Fallback.
- **LLM-Zugriff über eigenen Proxy**, damit der API-Key nicht auf dem Tablet liegt.
- **QR-Übergabe** (WLAN, Google-Maps-Transit-Route, Restaurant, Events) via `qr_flutter`.
- **Wetter:** meteoblue (ICON-D2, gut für Föhn); **Events:** rausgegangen.de, Zeitraum heute bis +3 Tage (`lib/services/links.dart`).

## Offen (Roadmap)
- Spracheingabe/-ausgabe (`speech_to_text`, `flutter_tts`), Sprachbanner statt Pop-up, Sprach-Dropdown mit Endonymen
- Kiosk-Modus (Lock Task Mode / Device Owner), Wake-on-Approach (Frontkamera), Nachtabdunkelung
- Gedächtnis persistieren (`shared_preferences`)
- Events: "München mit Vergnügen" als zweite Quelle
- Apotheken/Supermärkte mit Öffnungszeiten (Google Places API)

## Start
`flutter create . --platforms android` (einmalig, erzeugt `android/`), dann `flutter pub get && flutter run`.
