import 'dart:convert';
import 'package:http/http.dart' as http;
import 'memory_store.dart';

class LlmReply {
  LlmReply(this.text, this.lang, this.actions, this.remember);
  final String text;
  final String lang;
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic>? remember;
}

class LlmService {
  LlmService({required this.endpoint, required this.apiKeyProvider, required this.memory});
  final String endpoint; // eigener Proxy, damit der Key nicht auf dem Tablet liegt
  final Future<String> Function() apiKeyProvider;
  final MemoryStore memory;
  final List<Map<String, String>> _history = [];
  String? forcedLang; // gesetzt, wenn der Gast per Dropdown gewählt hat

  static const _system = '''
Du bist der Concierge einer Airbnb-Wohnung in München. Erkenne die Sprache des Gastes
und antworte in genau dieser Sprache. Nutze die Wohnungsdaten (deutsch) als Wissensquelle.
Frage bei Unklarheiten kurz nach (z.B. Suchradius, Küche, Art des Events).
Merke dir Präferenzen des Gastes über "remember" (z.B. {"radius_m":"800","kueche":"vegetarisch"}) und nutze sie.
Antworte ausschließlich als JSON:
{"lang":"<iso>","text":"...","remember":{},"actions":[...]}
Aktionen:
 {"type":"wifi_qr"}
 {"type":"route_qr","from":"..","to":".."}  (ÖPNV, Google Maps travelmode=transit)
 {"type":"places","kind":"pharmacy|supermarket|bakery|drugstore|restaurant","radius_m":1000}
 {"type":"events"}  (App liefert danach Eventtexte; dann auswählen und empfehlen)
 {"type":"weather"} {"type":"checkout"}
Notruf: 110, 112, 116117. Nach 20 Uhr und sonntags auf Öffnungszeiten und Sonntags-Alternativen hinweisen.
''';

  Future<LlmReply> ask(String userText, String wohnungJson, {String? extraContext}) async {
    _history.add({'role': 'user', 'content': userText});
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {'content-type': 'application/json', 'x-api-key': await apiKeyProvider()},
      body: jsonEncode({
        'system': '$_system\nWohnung: $wohnungJson\nGedächtnis: ${jsonEncode(memory.data)}\n'
            '${forcedLang != null ? "Antworte immer auf: $forcedLang\n" : ""}'
            '${extraContext != null ? "Zusatzdaten:\n$extraContext\n" : ""}'
            'Jetzt: ${DateTime.now().toIso8601String()}',
        'messages': _history,
      }),
    );
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    _history.add({'role': 'assistant', 'content': j['text'] as String});
    final r = LlmReply(j['text'], j['lang'] ?? 'de',
        List<Map<String, dynamic>>.from(j['actions'] ?? []), j['remember']);
    await memory.merge(r.remember);
    return r;
  }

  void resetConversation() => _history.clear();
}
