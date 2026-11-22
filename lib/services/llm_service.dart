import 'dart:convert';
import 'package:http/http.dart' as http;

/// Antwort der LLM: Text in Gastsprache plus optionale Aktionen fürs UI.
class LlmReply {
  LlmReply(this.text, this.lang, this.actions);
  final String text;
  final String lang; // z.B. "es"
  final List<Map<String, dynamic>> actions; // z.B. {type:"wifi_qr"}, {type:"route_qr", url:"..."}
}

class LlmService {
  LlmService({required this.endpoint, required this.apiKeyProvider});
  final String endpoint; // eigener Proxy empfohlen, damit der Key nicht im Tablet liegt
  final Future<String> Function() apiKeyProvider;
  final List<Map<String, String>> _history = [];
  final Map<String, String> memory = {}; // gemerkte Gastpräferenzen (Radius, Küche, ...)

  static const _system = '''
Du bist der Concierge einer Airbnb-Wohnung in München. Erkenne die Sprache des Gastes
und antworte in genau dieser Sprache. Nutze die Wohnungsdaten (deutsch) als Wissensquelle.
Frage bei Unklarheiten kurz nach (Radius, Küche, Eventart). Antworte ausschließlich als JSON:
{"lang":"<iso>","text":"...","actions":[{"type":"wifi_qr"|"route_qr"|"place_qr"|"weather"|"events"|"checkout"|"emergency","url":"..."}]}
ÖPNV-Routen: Google-Maps-URL mit travelmode=transit. Notruf: 110, 112, 116117.
Sonntags/nach 20 Uhr: auf Öffnungszeiten und Sonntags-Alternativen hinweisen.
''';

  Future<LlmReply> ask(String userText, String wohnungJson) async {
    _history.add({'role': 'user', 'content': userText});
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {'content-type': 'application/json', 'x-api-key': await apiKeyProvider()},
      body: jsonEncode({
        'system': '$_system\nWohnung: $wohnungJson\nGedächtnis: ${jsonEncode(memory)}\n'
            'Jetzt: ${DateTime.now().toIso8601String()}',
        'messages': _history,
      }),
    );
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    _history.add({'role': 'assistant', 'content': j['text'] as String});
    return LlmReply(j['text'], j['lang'] ?? 'de', List<Map<String, dynamic>>.from(j['actions'] ?? []));
  }
}
