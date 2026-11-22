# Concierge for Airbnb

Wand-Tablet (Android) für Gäste einer Airbnb-Wohnung in München. Mehrsprachig per Sprache oder Text.

## Architektur
- **Flutter** (Android-Tablet). Avalonia wird nicht gebraucht: zwei UI-Stacks doppeln nur die Arbeit.
- **`assets/wohnung.json`** wird nur auf Deutsch gepflegt und bei jeder Frage unsichtbar als Kontext an die LLM gegeben. Die LLM antwortet in der erkannten Gastsprache.
- **Update ohne neuen Build:** `WohnungRepository.remoteUrl` auf die GitHub-raw-URL der Datei setzen; Asset ist Offline-Fallback.
- **LLM-Zugriff über eigenen Proxy**, damit der API-Key nicht auf dem Tablet liegt.
- **QR-Übergabe** (WLAN, Google-Maps-Transit-Route, Restaurant, Events) via `qr_flutter`.
- **Wetter:** meteoblue (ICON-D2, gut für Föhn); **Events:** rausgegangen.de, Zeitraum heute bis +3 Tage (`lib/services/links.dart`).

## Umgesetzt
- Sprachein-/ausgabe (`speech_to_text`, `flutter_tts`), Endonym-Dropdown, dezentes Sprachbanner
- Gedächtnis dauerhaft (`MemoryStore`, die LLM liefert `remember`)
- Events: rausgegangen.de + München mit Vergnügen (Text wird der LLM als Kontext gegeben)
- Google Places (Öffnungszeiten, offen/zu), Key per `--dart-define=PLACES_KEY=...`
- Wake-on-Approach (Frontkamera, nur Bewegungsdifferenz, nichts wird gespeichert) und Nachtdimmung 22-7 Uhr
- Kiosk: Lock-Task-Modus über `tool/setup_android.sh`

## Start
```
tool/setup_android.sh
flutter pub get
flutter run --dart-define=LLM_ENDPOINT=https://dein-proxy --dart-define=LLM_KEY=... --dart-define=PLACES_KEY=...
```

## Bekannte Grenzen
- Android-STT erkennt die Sprache nicht selbst. Es wird in der gewählten Sprache gehört; schreibt/spricht der Gast in einer anderen, erkennt die LLM sie am Text und die App wechselt.
- Echter Kiosk ohne Dialog braucht Device Owner (`adb shell dpm set-device-owner ...` mit eigenem DeviceAdminReceiver) oder Bildschirm-Anheften in den Android-Einstellungen.
- Eventseiten haben keine API; die HTML-Auswertung durch die LLM kann brechen. URL von München mit Vergnügen bitte prüfen.
- Nicht kompiliert oder auf einem Gerät getestet (kein Flutter in der Entwicklungsumgebung).
