import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'memory_store.dart';

class LlmReply {
  LlmReply(this.text, this.lang, this.actions, this.remember);
  final String text;
  final String lang;
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic>? remember;
}

/// LLM läuft komplett auf dem Tablet (Gemma über MediaPipe/flutter_gemma).
/// Kein Server, kein API-Key. Modelldatei einmalig per adb auf das Gerät kopieren (siehe README).
/// Hinweis: API von flutter_gemma ändert sich zwischen Versionen; bei Compile-Fehlern
/// hier anpassen (alles Plugin-Spezifische steht nur in [init] und [_generate]).
class LlmService {
  LlmService({required this.memory});
  final MemoryStore memory;
  final List<(String, String)> _history = []; // (rolle, text), kurz halten wegen Kontextgröße
  String? forcedLang;
  dynamic _model;

  static const modelPath = String.fromEnvironment('MODEL_PATH',
      defaultValue: '/storage/emulated/0/Android/data/de.concierge.concierge_airbnb/files/model.task');

  Future<void> init() async {
    await FlutterGemma.installModel(modelType: ModelType.gemmaIt).fromFile(modelPath).install();
    _model = await FlutterGemma.getActiveModel(maxTokens: 4096);
  }

  static const _system = '''
Du bist der Concierge einer Airbnb-Wohnung in München. Antworte in der Sprache des Gastes,
kurz und freundlich. Nutze nur die Wohnungsdaten (deutsch). Frage bei Unklarheit kurz nach
(Radius, Küche, Art des Events). Antworte NUR mit JSON:
{"lang":"<iso>","text":"...","remember":{},"actions":[]}
Aktionen: {"type":"wifi_qr"} {"type":"route_qr","from":"..","to":".."} {"type":"weather"}
{"type":"places","kind":"pharmacy|supermarket|bakery|drugstore|restaurant","radius_m":1000}
{"type":"events"} {"type":"checkout"}
"remember": Präferenzen des Gastes, z.B. {"radius_m":"800"}.
Nach 20 Uhr und sonntags auf Öffnungszeiten und Sonntags-Alternativen hinweisen.
''';

  Future<LlmReply> ask(String userText, String wohnungJson, {String? extraContext}) async {
    final hist = _history.length > 6 ? _history.sublist(_history.length - 6) : _history;
    final prompt = StringBuffer()
      ..writeln(_system)
      ..writeln('Wohnung: $wohnungJson')
      ..writeln('Gedächtnis: ${jsonEncode(memory.data)}')
      ..writeln(forcedLang != null ? 'Antworte immer auf: $forcedLang' : '')
      ..writeln(extraContext != null ? 'Zusatzdaten:\n$extraContext' : '')
      ..writeln('Jetzt: ${DateTime.now().toIso8601String()}');
    for (final h in hist) {
      prompt.writeln('${h.$1}: ${h.$2}');
    }
    prompt.writeln('Gast: $userText\nJSON:');
    final raw = await _generate(prompt.toString());
    _history..add(('Gast', userText))..add(('Concierge', raw));
    final r = _parse(raw);
    await memory.merge(r.remember);
    return r;
  }

  Future<String> _generate(String prompt) async {
    final chat = await _model.createChat();
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final resp = await chat.generateChatResponse();
    return resp is String ? resp : (resp as dynamic).token ?? '$resp';
  }

  /// Kleine Modelle liefern oft JSON mit Drumherum oder gar kein JSON: tolerant lesen.
  LlmReply _parse(String raw) {
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (m != null) {
      try {
        final j = jsonDecode(m.group(0)!);
        return LlmReply(j['text'] ?? raw, j['lang'] ?? 'de',
            List<Map<String, dynamic>>.from(j['actions'] ?? []), j['remember']);
      } catch (_) {}
    }
    return LlmReply(raw.trim(), 'de', [], null);
  }

  void resetConversation() => _history.clear();
}
