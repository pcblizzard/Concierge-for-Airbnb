import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/display_service.dart';
import 'services/events_service.dart';
import 'services/languages.dart';
import 'services/links.dart';
import 'services/llm_service.dart';
import 'services/memory_store.dart';
import 'services/places_service.dart';
import 'services/voice_service.dart';
import 'services/wohnung_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final repo = WohnungRepository(
      // remoteUrl: 'https://raw.githubusercontent.com/<user>/<repo>/main/assets/wohnung.json',
      );
  await repo.load();
  final memory = MemoryStore();
  await memory.load();
  runApp(ConciergeApp(repo: repo, memory: memory));
}

class ConciergeApp extends StatelessWidget {
  const ConciergeApp({super.key, required this.repo, required this.memory});
  final WohnungRepository repo;
  final MemoryStore memory;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Concierge',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        home: HomeScreen(repo: repo, memory: memory),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.memory});
  final WohnungRepository repo;
  final MemoryStore memory;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _voice = VoiceService();
  final _display = DisplayService();
  final _places = PlacesService();
  final _events = EventsService();
  late final LlmService _llm = LlmService(
      endpoint: const String.fromEnvironment('LLM_ENDPOINT', defaultValue: 'https://example.invalid/concierge'),
      apiKeyProvider: () async => const String.fromEnvironment('LLM_KEY'),
      memory: widget.memory);

  Lang _lang = languages.first;
  bool _langBanner = false;
  bool _listening = false;
  bool _busy = false;
  String _answer = '';
  String? _qr;
  List<Place> _placeList = [];
  List<String> _checks = [];
  final Set<int> _done = {};

  @override
  void initState() {
    super.initState();
    _display.start().catchError((_) {});
  }

  @override
  void dispose() {
    _display.dispose();
    super.dispose();
  }

  void _setLang(Lang l, {bool manual = false}) {
    setState(() {
      _lang = l;
      _langBanner = !manual;
    });
    _llm.forcedLang = manual ? l.endonym : null;
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _display.touch();
    setState(() => _busy = true);
    try {
      var r = await _llm.ask(text, widget.repo.contextForLlm);
      // Zweiter Durchgang, wenn die LLM Eventdaten braucht.
      if (r.actions.any((a) => a['type'] == 'events')) {
        r = await _llm.ask('(Eventdaten angefordert, bitte jetzt empfehlen)', widget.repo.contextForLlm,
            extraContext: await _events.snippets());
      }
      final detected = langByCode(r.lang);
      if (detected.code != _lang.code && _llm.forcedLang == null) _setLang(detected);
      final newQr = await _applyActions(r.actions);
      setState(() {
        _answer = r.text;
        _qr = newQr;
      });
      _voice.speak(r.text, _lang);
    } catch (e) {
      setState(() => _answer = '⚠ $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<String?> _applyActions(List<Map<String, dynamic>> actions) async {
    String? qr;
    _placeList = [];
    _checks = [];
    for (final a in actions) {
      switch (a['type']) {
        case 'wifi_qr':
          qr = widget.repo.wifiQrPayload;
        case 'route_qr':
          qr = transitRoute('${a['from'] ?? widget.repo.data['adresse']?['text']}', '${a['to']}');
        case 'weather':
          qr = meteoblueMuenchen;
        case 'events':
          qr = rausgegangenUrl();
        case 'places':
          final addr = widget.repo.data['adresse'] ?? {};
          _placeList = await _places.nearby(
              (addr['lat'] ?? 48.1351).toDouble(), (addr['lng'] ?? 11.582).toDouble(),
              ['${a['kind']}'], (a['radius_m'] ?? int.tryParse(widget.memory.data['radius_m'] ?? '') ?? 1000) as int);
          if (_placeList.isNotEmpty) qr = _placeList.first.mapsUri;
        case 'checkout':
          _checks = List<String>.from(widget.repo.data['checkout']?['checkliste'] ?? []);
          _done.clear();
      }
    }
    return qr;
  }

  Future<void> _mic() async {
    _display.touch();
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _voice.listen(_lang, (t, done) {
      _ctrl.text = t;
      if (done) {
        setState(() => _listening = false);
        _send(t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notruf = (widget.repo.data['notruf'] as List?) ?? [];
    return Listener(
      onPointerDown: (_) => _display.touch(),
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            _topBar(),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ListView(children: [
                      Text(_answer, style: const TextStyle(fontSize: 28)),
                      for (final p in _placeList)
                        ListTile(
                          title: Text(p.name),
                          subtitle: Text('${p.address}\n${p.hoursToday ?? ''}'),
                          trailing: Icon(Icons.circle, color: p.openNow == null ? Colors.grey : p.openNow! ? Colors.green : Colors.red),
                        ),
                      for (var i = 0; i < _checks.length; i++)
                        CheckboxListTile(
                          value: _done.contains(i),
                          title: Text(_checks[i], style: const TextStyle(fontSize: 22)),
                          onChanged: (v) => setState(() => v! ? _done.add(i) : _done.remove(i)),
                        ),
                    ]),
                  ),
                  if (_qr != null)
                    Column(children: [
                      QrImageView(data: _qr!, size: 260, backgroundColor: Colors.white),
                      const SizedBox(height: 8),
                      const Text('📱 Scan'),
                    ]),
                ]),
              ),
            ),
            Wrap(spacing: 12, children: [
              for (final c in const {
                'WLAN': 'WLAN',
                'ÖPNV': 'Wie komme ich mit dem ÖPNV zu ...',
                'Essen': 'Restaurant in der Nähe',
                'Events': 'Was kann ich die nächsten Tage unternehmen?',
                'Wetter': 'Wetter',
                'Apotheke': 'Nächste Apotheke mit Öffnungszeiten',
                'Sonntags-Rettung': 'Wo bekomme ich sonntags Lebensmittel?',
                'Check-out': 'Check-out Checkliste',
              }.entries)
                ActionChip(label: Text(c.key), onPressed: () => _send(c.value)),
            ]),
            Container(
              color: Colors.red.shade700,
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final n in notruf)
                  Text('${n['name']}: ${n['nummer']}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                IconButton.filled(
                    iconSize: 36, onPressed: _mic, icon: Icon(_listening ? Icons.stop : Icons.mic)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (t) {
                      _send(t);
                      _ctrl.clear();
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar() => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          if (_langBanner)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _langBanner = false),
                child: Text('${_lang.endonym} ✓  –  ✎', style: const TextStyle(fontSize: 16)),
              ),
            )
          else
            const Spacer(),
          DropdownButton<Lang>(
            value: _lang,
            underline: const SizedBox(),
            items: [for (final l in languages) DropdownMenuItem(value: l, child: Text(l.endonym))],
            onChanged: (l) => _setLang(l!, manual: true),
          ),
        ]),
      );
}
