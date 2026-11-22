import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'languages.dart';

class VoiceService {
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;

  Future<bool> init() async => _ready = await _stt.initialize();

  /// Android-STT erkennt die Sprache nicht selbst: es wird in der aktuell
  /// gewählten Sprache gehört. Erkennt die LLM am Text eine andere Sprache,
  /// wechselt die App und zeigt das Banner.
  Future<void> listen(Lang lang, void Function(String text, bool done) onResult) async {
    if (!_ready && !await init()) return;
    await _stt.listen(
      localeId: lang.stt.replaceAll('-', '_'),
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stopListening() => _stt.stop();

  Future<void> speak(String text, Lang lang) async {
    await _tts.setLanguage(lang.stt);
    await _tts.speak(text);
  }
}
