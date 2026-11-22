import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Places API (New). Key: --dart-define=PLACES_KEY=... (Key in der
/// Cloud Console auf die App-ID und die Places API beschränken).
const _key = String.fromEnvironment('PLACES_KEY');

class Place {
  Place(this.name, this.address, this.openNow, this.hoursToday, this.mapsUri);
  final String name, address;
  final bool? openNow;
  final String? hoursToday;
  final String mapsUri;
  Map<String, dynamic> toJson() => {
        'name': name, 'address': address, 'openNow': openNow,
        'hours': hoursToday, 'maps': mapsUri,
      };
}

class PlacesService {
  /// [types] z.B. ['pharmacy'], ['supermarket'], ['bakery'], ['drugstore'], ['restaurant'].
  Future<List<Place>> nearby(double lat, double lng, List<String> types, int radiusM) async {
    final res = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: {
        'content-type': 'application/json',
        'X-Goog-Api-Key': _key,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,'
            'places.currentOpeningHours,places.regularOpeningHours,places.googleMapsUri',
      },
      body: jsonEncode({
        'includedTypes': types,
        'maxResultCount': 8,
        'rankPreference': 'DISTANCE',
        'languageCode': 'de',
        'locationRestriction': {
          'circle': {'center': {'latitude': lat, 'longitude': lng}, 'radius': radiusM.toDouble()}
        },
      }),
    );
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    final today = DateTime.now().weekday % 7; // Places: 0 = Sonntag
    return [
      for (final p in (j['places'] as List? ?? []))
        Place(
          p['displayName']?['text'] ?? '?',
          p['formattedAddress'] ?? '',
          p['currentOpeningHours']?['openNow'],
          _today(p['regularOpeningHours']?['weekdayDescriptions'], today),
          p['googleMapsUri'] ?? '',
        )
    ];
  }

  // weekdayDescriptions beginnt mit Montag.
  String? _today(List? d, int sundayZero) =>
      d == null || d.isEmpty ? null : d[(sundayZero + 6) % 7] as String;
}
