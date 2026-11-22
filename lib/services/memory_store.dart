import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Dauerhaftes Gedächtnis (Radius, Küche, Sprache, ...).
/// Wird beim Check-out über [clear] geleert, damit nichts zum nächsten Gast wandert.
class MemoryStore {
  static const _k = 'memory_v1';
  Map<String, String> data = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_k);
    if (s != null) data = Map<String, String>.from(jsonDecode(s));
  }

  Future<void> merge(Map<String, dynamic>? m) async {
    if (m == null || m.isEmpty) return;
    data.addAll(m.map((k, v) => MapEntry(k, '$v')));
    (await SharedPreferences.getInstance()).setString(_k, jsonEncode(data));
  }

  Future<void> clear() async {
    data = {};
    (await SharedPreferences.getInstance()).remove(_k);
  }
}
