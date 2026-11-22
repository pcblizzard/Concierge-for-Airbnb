import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/links.dart';
import 'services/llm_service.dart';
import 'services/wohnung_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final repo = WohnungRepository(
      // remoteUrl: 'https://raw.githubusercontent.com/<user>/<repo>/main/assets/wohnung.json',
      );
  await repo.load();
  runApp(ConciergeApp(repo: repo));
}

class ConciergeApp extends StatelessWidget {
  const ConciergeApp({super.key, required this.repo});
  final WohnungRepository repo;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Concierge',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        home: HomeScreen(repo: repo),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo});
  final WohnungRepository repo;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  late final LlmService _llm = LlmService(
      endpoint: 'https://example.invalid/concierge', apiKeyProvider: () async => '');
  String _answer = '';
  String _lang = 'de';
  String? _qr;

  Future<void> _send(String text) async {
    final r = await _llm.ask(text, widget.repo.contextForLlm);
    setState(() {
      _answer = r.text;
      _lang = r.lang;
      _qr = null;
      for (final a in r.actions) {
        if (a['type'] == 'wifi_qr') _qr = widget.repo.wifiQrPayload;
        if (a['url'] != null) _qr = a['url'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notruf = (widget.repo.data['notruf'] as List?) ?? [];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (_lang != 'de')
            MaterialBanner(
                content: Text('Language: $_lang – tap to change'),
                actions: [TextButton(onPressed: () {}, child: const Text('Ändern'))]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                Expanded(child: SingleChildScrollView(child: Text(_answer, style: const TextStyle(fontSize: 28)))),
                if (_qr != null) QrImageView(data: _qr!, size: 260, backgroundColor: Colors.white),
              ]),
            ),
          ),
          Wrap(spacing: 12, children: [
            ActionChip(label: const Text('WLAN'), onPressed: () => _send('WLAN')),
            ActionChip(label: const Text('ÖPNV'), onPressed: () => _send('Wie komme ich mit dem ÖPNV zu ...')),
            ActionChip(label: const Text('Essen'), onPressed: () => _send('Restaurant in der Nähe')),
            ActionChip(label: const Text('Events'), onPressed: () => setState(() => _qr = rausgegangenUrl())),
            ActionChip(label: const Text('Wetter'), onPressed: () => setState(() => _qr = meteoblueMuenchen)),
            ActionChip(label: const Text('Apotheke'), onPressed: () => _send('Nächste Apotheke mit Öffnungszeiten')),
            ActionChip(label: const Text('Sonntags-Rettung'), onPressed: () => _send('Wo bekomme ich sonntags Lebensmittel?')),
            ActionChip(label: const Text('Check-out'), onPressed: () => _send('Check-out Checkliste')),
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
            child: TextField(
              controller: _ctrl,
              onSubmitted: _send,
              decoration: const InputDecoration(hintText: '🎤 / ⌨', border: OutlineInputBorder()),
            ),
          ),
        ]),
      ),
    );
  }
}
