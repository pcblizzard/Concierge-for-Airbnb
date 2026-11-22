import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Lädt wohnung.json. Bevorzugt eine Remote-URL (z.B. GitHub raw),
/// fällt auf das mitgelieferte Asset zurück.
class WohnungRepository {
  WohnungRepository({this.remoteUrl});
  final String? remoteUrl;
  Map<String, dynamic> data = {};

  Future<void> load() async {
    if (remoteUrl != null) {
      try {
        final r = await http.get(Uri.parse(remoteUrl!)).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          data = jsonDecode(utf8.decode(r.bodyBytes));
          return;
        }
      } catch (_) {}
    }
    data = jsonDecode(await rootBundle.loadString('assets/wohnung.json'));
  }

  /// Unsichtbarer Kontext für die LLM.
  String get contextForLlm => jsonEncode(data);

  String get wifiQrPayload {
    final w = data['wlan'] ?? {};
    return 'WIFI:T:${w['verschluesselung'] ?? 'WPA'};S:${w['name']};P:${w['passwort']};;';
  }
}
