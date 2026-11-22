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

## Ohne Server
Die LLM läuft auf dem Tablet (Gemma über MediaPipe, Paket `flutter_gemma`). Kein Proxy, kein API-Key.
Nur Places, Events wie Wetterlinks brauchen das WLAN. Ohne geladenes Modell beantwortet die App WLAN und Check-out trotzdem.

Modell wählen (Hugging Face, Lizenz akzeptieren), als `.task`-Datei:
- Gemma 3n E2B (ca. 3 GB, besser bei vielen Sprachen, braucht ca. 6 GB RAM)
- Gemma 3 1B int4 (ca. 0,5 GB, läuft auf schwachen Tablets, bei Türkisch & Co. spürbar schwächer)

```
adb push model.task /sdcard/Android/data/de.concierge.concierge_airbnb/files/model.task
```

## Start
```
tool/setup_android.sh
flutter pub get
flutter run --dart-define=PLACES_KEY=...
```
Kiosk: Android-Einstellungen > Sicherheit > Erweitert > App-Anheftung einschalten. Die App heftet sich beim Start selbst an
(einmal Bestätigen). Beenden: lange auf die Sprachleiste oben drücken, PIN aus `wohnung.json` (`admin_pin`, bitte ändern).

## Bekannte Grenzen
- Android-STT erkennt die Sprache nicht selbst. Es wird in der gewählten Sprache gehört; schreibt/spricht der Gast in einer anderen, erkennt die LLM sie am Text und die App wechselt.
- Kleine On-Device-Modelle halten das JSON-Format nicht immer ein. Die App liest tolerant und zeigt sonst den Rohtext.
- Eventseiten haben keine API; die Auswertung kann brechen.
- Nicht kompiliert oder getestet (kein Flutter in der Entwicklungsumgebung). Die `flutter_gemma`-API ist am ehesten anzupassen (`LlmService.init/_generate`).
