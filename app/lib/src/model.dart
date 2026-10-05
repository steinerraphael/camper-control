/// The state the controller reports: switches, sensors, protection.
///
/// Parsing never throws on an unexpected value. A newer controller that
/// sends a field this app does not know must not crash an older app.
library;

class SwitchState {
  const SwitchState({
    required this.id,
    required this.name,
    required this.on,
    this.locked = false,
    this.loadA = 0,
  });

  final String id;
  final String name;
  final bool on;
  final bool locked;
  final double loadA;

  factory SwitchState.fromJson(Map<String, dynamic> j) => SwitchState(
        id: _str(j['id']) ?? '',
        name: _str(j['name']) ?? _str(j['id']) ?? '',
        on: _bool(j['on'], false),
        locked: _bool(j['locked'], false),
        loadA: _num(j['load_a']) ?? 0,
      );

  SwitchState copyWith({bool? on, bool? locked}) => SwitchState(
        id: id,
        name: name,
        on: on ?? this.on,
        locked: locked ?? this.locked,
        loadA: loadA,
      );
}

enum SensorKind { battery, temperature, unknown }

class SensorState {
  const SensorState({
    required this.id,
    required this.name,
    required this.kind,
    this.values = const {},
    this.error,
    this.capacityAh,
  });

  final String id;
  final String name;
  final SensorKind kind;
  final Map<String, double> values;
  final String? error;
  final double? capacityAh;

  double? get voltage => values['voltage'];
  double? get current => values['current'];
  double? get power => values['power'];
  double? get temperature => values['temperature'];

  factory SensorState.fromJson(Map<String, dynamic> j) {
    final raw = j['values'];
    final values = <String, double>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = _num(e.value);
        if (v != null) values[e.key.toString()] = v;
      }
    }
    return SensorState(
      id: _str(j['id']) ?? '',
      name: _str(j['name']) ?? _str(j['id']) ?? '',
      kind: switch (j['type']) {
        'ina226' => SensorKind.battery,
        'ds18b20' => SensorKind.temperature,
        _ => SensorKind.unknown,
      },
      values: values,
      error: _str(j['error']),
      capacityAh: _num(j['capacity_ah']),
    );
  }
}

class Protection {
  const Protection({
    this.enabled = false,
    this.active = false,
    this.cutoffV,
    this.recoverV,
  });

  final bool enabled;
  final bool active;
  final double? cutoffV;
  final double? recoverV;

  factory Protection.fromJson(Map<String, dynamic>? j) => j == null
      ? const Protection()
      : Protection(
          enabled: _bool(j['enabled'], false),
          active: _bool(j['active'], false),
          cutoffV: _num(j['cutoff_v']),
          recoverV: _num(j['recover_v']),
        );
}

class CamperState {
  const CamperState({
    this.switches = const [],
    this.sensors = const [],
    this.protection = const Protection(),
  });

  final List<SwitchState> switches;
  final List<SensorState> sensors;
  final Protection protection;

  Iterable<SensorState> get batteries => sensors.where((s) => s.kind == SensorKind.battery);
  Iterable<SensorState> get thermometers => sensors.where((s) => s.kind == SensorKind.temperature);

  factory CamperState.fromJson(Map<String, dynamic> j) => CamperState(
        switches: _list(j['switches']).map(SwitchState.fromJson).toList(),
        sensors: _list(j['sensors']).map(SensorState.fromJson).toList(),
        protection: Protection.fromJson(_map(j['protection'])),
      );
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

String? _str(Object? v) => v is String ? v : null;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

Iterable<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>() : const [];
