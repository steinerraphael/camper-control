import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/camper_api.dart';
import 'api/demo_camper_api.dart';
import 'api/http_camper_api.dart';
import 'model.dart';

/// Built for GitHub Pages with `--dart-define=DEMO=true`: there is no Pi
/// behind that address, so the app starts in demo mode.
const _demoBuild = bool.fromEnvironment('DEMO');

enum ConnectionMode { demo, live }

class Settings {
  const Settings({required this.mode, required this.baseUrl});
  final ConnectionMode mode;
  final String baseUrl;
}

final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('overridden in main()'),
);

/// Where the controller lives when nothing was configured. Served by the Pi,
/// the app is on the controller's own address; as a native app it has to
/// guess, and `camper.local` is what install.sh's hostname advice gives.
String defaultBaseUrl() =>
    kIsWeb && Uri.base.scheme.startsWith('http') ? Uri.base.origin : 'http://camper.local:8080';

class SettingsNotifier extends Notifier<Settings> {
  static const _modeKey = 'mode';
  static const _urlKey = 'base_url';

  @override
  Settings build() {
    final prefs = ref.watch(prefsProvider);
    final storedMode = prefs.getString(_modeKey);
    return Settings(
      mode: ConnectionMode.values.where((m) => m.name == storedMode).firstOrNull ??
          (_demoBuild ? ConnectionMode.demo : ConnectionMode.live),
      baseUrl: prefs.getString(_urlKey) ?? defaultBaseUrl(),
    );
  }

  Future<void> update({ConnectionMode? mode, String? baseUrl}) async {
    final prefs = ref.read(prefsProvider);
    if (mode != null) await prefs.setString(_modeKey, mode.name);
    if (baseUrl != null) await prefs.setString(_urlKey, baseUrl);
    state = Settings(mode: mode ?? state.mode, baseUrl: baseUrl ?? state.baseUrl);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final apiProvider = Provider<CamperApi>((ref) {
  final s = ref.watch(settingsProvider);
  final CamperApi api = switch (s.mode) {
    ConnectionMode.demo => DemoCamperApi(),
    ConnectionMode.live => HttpCamperApi(Uri.parse(s.baseUrl)),
  };
  ref.onDispose(api.dispose);
  return api;
});

final camperStateProvider = StreamProvider<CamperState>(
  (ref) => ref.watch(apiProvider).watch(),
);

final connectedProvider = StreamProvider<bool>(
  (ref) => ref.watch(apiProvider).connection,
);

/// Recent temperatures per sensor, for the sparklines. Kept on the client:
/// a few minutes of trend is a display nicety, not data worth storing.
class TemperatureHistory extends Notifier<Map<String, List<double>>> {
  static const maxPoints = 90;

  @override
  Map<String, List<double>> build() {
    ref.watch(apiProvider); // a new connection starts a new history
    ref.listen(camperStateProvider, (_, next) {
      final s = next.valueOrNull;
      if (s == null) return;
      final updated = {...state};
      for (final t in s.thermometers) {
        final v = t.temperature;
        if (v == null) continue;
        final list = [...?updated[t.id], v];
        updated[t.id] = list.length > maxPoints ? list.sublist(list.length - maxPoints) : list;
      }
      state = updated;
    });
    return const {};
  }
}

final temperatureHistoryProvider =
    NotifierProvider<TemperatureHistory, Map<String, List<double>>>(TemperatureHistory.new);

/// When the last state arrived, for the "updated" line on the start page.
/// Recomputed on every new state, so "now" is the arrival time.
final lastUpdateProvider = Provider<DateTime?>(
  (ref) => ref.watch(camperStateProvider).hasValue ? DateTime.now() : null,
);

enum AppPage { start, switches, energy, climate, settings }

final pageProvider = StateProvider<AppPage>((_) => AppPage.start);
