import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/demo_camper_api.dart';
import '../../providers.dart';
import '../common.dart';
import '../glass.dart';
import '../theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Created eagerly: a lazy controller first touched in dispose() would read
  // ref after the widget is gone (demo mode never shows the field).
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(settingsProvider).baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final api = ref.watch(apiProvider);
    // An https page (GitHub Pages) may not call an http address: the browser
    // blocks it as mixed content, whatever the server would have answered.
    final mixedContent =
        kIsWeb && Uri.base.scheme == 'https' && _url.text.trim().startsWith('http:');

    return PageBody(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Verbindung'),
                  SegmentedButton<ConnectionMode>(
                    segments: const [
                      ButtonSegment(
                        value: ConnectionMode.demo,
                        label: Text('Demo'),
                        icon: Icon(Icons.science_rounded),
                      ),
                      ButtonSegment(
                        value: ConnectionMode.live,
                        label: Text('Steuereinheit'),
                        icon: Icon(Icons.router_rounded),
                      ),
                    ],
                    selected: {settings.mode},
                    onSelectionChanged: (s) =>
                        ref.read(settingsProvider.notifier).update(mode: s.first),
                  ),
                  const SizedBox(height: 20),
                  if (settings.mode == ConnectionMode.live) ...[
                    const _Label('Adresse der Steuereinheit'),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'http://camper.local:8080',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        suffixIcon: IconButton(
                          tooltip: 'Übernehmen',
                          icon: const Icon(Icons.check_rounded),
                          onPressed: () =>
                              ref.read(settingsProvider.notifier).update(baseUrl: _url.text.trim()),
                        ),
                      ),
                      onSubmitted: (v) =>
                          ref.read(settingsProvider.notifier).update(baseUrl: v.trim()),
                    ),
                    if (mixedContent) ...[
                      const SizedBox(height: 10),
                      const _Hint(
                        'Diese Seite läuft über https und darf keine http-Adresse aufrufen. '
                        'Öffne die App direkt von der Steuereinheit (z. B. http://camper.local:8080) '
                        'oder nutze hier den Demo-Modus.',
                      ),
                    ],
                  ] else if (api is DemoCamperApi) ...[
                    const _Label('Szenario'),
                    SegmentedButton<DemoScenario>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: DemoScenario.normal, label: Text('Normal')),
                        ButtonSegment(value: DemoScenario.lowBattery, label: Text('Akku leer')),
                        ButtonSegment(value: DemoScenario.charging, label: Text('Laden')),
                      ],
                      selected: {api.scenario},
                      onSelectionChanged: (s) => setState(() => api.scenario = s.first),
                    ),
                    const SizedBox(height: 10),
                    const _Hint(
                      'Simuliertes Fahrzeug, nichts wird wirklich geschaltet. '
                      '„Akku leer“ löst nach 5 Sekunden den Unterspannungsschutz aus, '
                      '„Laden“ gibt die Verbraucher wieder frei.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
      );
}
