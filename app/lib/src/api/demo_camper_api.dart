import 'dart:async';
import 'dart:math' as math;

import '../model.dart';
import 'camper_api.dart';

/// What the simulated battery is doing. Picked in the settings sheet, so the
/// protection can be tried out without draining anything.
enum DemoScenario { normal, lowBattery, charging }

class _DemoSwitch {
  _DemoSwitch(this.id, this.name, this.loadA, this.shedPriority);
  final String id;
  final String name;
  final double loadA;
  final int? shedPriority;
  bool on = false;
  bool locked = false;
}

/// A simulated van, close enough to the Pi's behaviour to test the app with:
/// the same switches as the example configuration, a 230 Ah AGM battery,
/// and the same low-voltage protection rules.
///
/// The protection delay is 5 s here instead of 30 s, so a demo does not
/// need half a minute of patience.
class DemoCamperApi implements CamperApi {
  DemoCamperApi({bool autoTick = true}) {
    if (autoTick) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  static const cutoffV = 12.0;
  static const recoverV = 12.8;
  static const cutoffDelayS = 5;
  static const capacityAh = 230.0;

  final _switches = [
    _DemoSwitch('interior_lights', 'Innenbeleuchtung', 2.0, 3),
    _DemoSwitch('reading_lights', 'Leselampen', 0.5, 2),
    _DemoSwitch('water_pump', 'Wasserpumpe', 4.0, 1),
    _DemoSwitch('fridge', 'Kühlbox', 3.5, 4),
    _DemoSwitch('usb_sockets', 'USB-Steckdosen', 1.0, 2),
    _DemoSwitch('roof_fan', 'Dachlüfter', 1.5, null),
  ];

  final _states = StreamController<CamperState>.broadcast();
  Timer? _timer;
  DemoScenario _scenario = DemoScenario.normal;
  int _t = 0;
  int? _lowSince;
  bool _protectionActive = false;
  double _fridgeTemp = 9;

  DemoScenario get scenario => _scenario;

  set scenario(DemoScenario value) {
    _scenario = value;
    _emit();
  }

  /// Advances the simulation by one second. Public for tests.
  void tick() {
    _t++;
    final fridgeOn = _switches.firstWhere((s) => s.id == 'fridge').on;
    _fridgeTemp += fridgeOn ? (4 - _fridgeTemp) * 0.05 : (14 - _fridgeTemp) * 0.01;
    _checkProtection();
    _emit();
  }

  double get _load => _switches.where((s) => s.on).fold(0.0, (a, s) => a + s.loadA);

  double get _current => switch (_scenario) {
        DemoScenario.normal => -0.3 - _load, // the Pi itself and standby draw
        DemoScenario.lowBattery => -_load,
        DemoScenario.charging => 24 - _load, // alternator via booster
      };

  double get _voltage {
    final rest = switch (_scenario) {
      DemoScenario.normal => 12.72,
      DemoScenario.lowBattery => 11.85,
      DemoScenario.charging => 13.9,
    };
    final sag = math.max(0.0, -_current) * 0.012;
    final ripple = math.sin(_t / 3) * 0.01;
    return rest - sag + ripple;
  }

  void _checkProtection() {
    final v = _voltage;
    if (!_protectionActive) {
      if (v < cutoffV) {
        _lowSince ??= _t;
        if (_t - _lowSince! >= cutoffDelayS) {
          _protectionActive = true;
          for (final s in _switches.where((s) => s.shedPriority != null)) {
            s
              ..on = false
              ..locked = true;
          }
        }
      } else {
        _lowSince = null;
      }
    } else if (v >= recoverV) {
      _protectionActive = false;
      _lowSince = null;
      for (final s in _switches) {
        s.locked = false;
      }
    }
  }

  CamperState get _snapshot {
    final v = _voltage;
    final i = _current;
    return CamperState(
      switches: [
        for (final s in _switches)
          SwitchState(id: s.id, name: s.name, on: s.on, locked: s.locked, loadA: s.loadA),
      ],
      sensors: [
        SensorState(
          id: 'house_battery',
          name: 'Aufbaubatterie',
          kind: SensorKind.battery,
          capacityAh: capacityAh,
          values: {
            'voltage': _round(v, 2),
            'current': _round(i, 2),
            'power': _round(v * i, 1),
          },
        ),
        SensorState(
          id: 'inside_temp',
          name: 'Innenraum',
          kind: SensorKind.temperature,
          values: {'temperature': _round(19.5 + math.sin(_t / 40) * 1.2, 1)},
        ),
        SensorState(
          id: 'fridge_temp',
          name: 'Kühlbox innen',
          kind: SensorKind.temperature,
          values: {'temperature': _round(_fridgeTemp, 1)},
        ),
      ],
      protection: Protection(
        enabled: true,
        active: _protectionActive,
        cutoffV: cutoffV,
        recoverV: recoverV,
      ),
    );
  }

  void _emit() {
    if (!_states.isClosed) _states.add(_snapshot);
  }

  @override
  Stream<CamperState> watch() async* {
    yield _snapshot;
    yield* _states.stream;
  }

  @override
  Stream<bool> get connection => Stream.value(true);

  @override
  Future<CamperState> setSwitch(String id, bool on) async {
    final s = _switches.where((s) => s.id == id).firstOrNull;
    if (s == null) throw const ApiException('Diesen Schalter gibt es nicht.');
    if (on && s.locked) throw const SwitchLockedException();
    s.on = on;
    _emit();
    return _snapshot;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _states.close();
  }
}

double _round(double v, int digits) {
  final f = math.pow(10, digits);
  return (v * f).roundToDouble() / f;
}
