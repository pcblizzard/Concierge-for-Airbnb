import 'package:http/http.dart' as http;
import 'links.dart';

/// Holt Eventseiten als Rohtext und gibt sie der LLM als Kontext, damit sie
/// nach Wunsch des Gastes (Konzert, Sport, Oper, Ausgehen ...) auswählt.
/// Hinweis: Beide Seiten bieten keine offizielle API; HTML kann sich ändern.
/// URL für "München mit Vergnügen" bitte prüfen und ggf. anpassen.
const muenchenMitVergnuegenUrl = 'https://www.muenchen-mit-vergnuegen.de/';

class EventsService {
  Future<String> snippets() async {
    final out = StringBuffer();
    for (final e in {'rausgegangen': rausgegangenUrl(), 'muenchen_mit_vergnuegen': muenchenMitVergnuegenUrl}.entries) {
      try {
        final r = await http.get(Uri.parse(e.value)).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          final text = r.body
              .replaceAll(RegExp(r'<(script|style)[\s\S]*?</\1>'), ' ')
              .replaceAll(RegExp(r'<[^>]+>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ');
          out.writeln('[${e.key}] ${e.value}\n${text.substring(0, text.length.clamp(0, 6000))}\n');
        }
      } catch (_) {}
    }
    return out.toString();
  }
}
