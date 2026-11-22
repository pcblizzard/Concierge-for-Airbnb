/// URL-Bauer für Übergabe ans Gäste-Handy (QR-Code).
String transitRoute(String from, String to) =>
    'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(from)}'
    '&destination=${Uri.encodeComponent(to)}&travelmode=transit';

/// Rausgegangen: heute bis heute+3 Tage.
String rausgegangenUrl([DateTime? now]) {
  final s = now ?? DateTime.now();
  final e = s.add(const Duration(days: 3));
  String d(DateTime t) => t.toIso8601String().substring(0, 10);
  return 'https://rausgegangen.de/muenchen/eventsbydate/?geospatial_query_type=CITY'
      '&lat=48.1351&lng=11.582&city=muenchen&active_city_name=M%C3%BCnchen'
      '&start_date=${d(s)}&end_date=${d(e)}';
}

const meteoblueMuenchen = 'https://www.meteoblue.com/de/wetter/woche/m%C3%BCnchen_deutschland_2867714';
