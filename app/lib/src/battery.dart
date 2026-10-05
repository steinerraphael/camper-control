/// State-of-charge estimate for an AGM battery, from voltage alone.
///
/// This is an estimate and the UI says so. Voltage only tracks charge at
/// rest; under load it sags, so the discharge current is added back through
/// a typical internal resistance. While charging the voltage says nothing
/// about the charge at all, and the estimate is withheld rather than guessed.
library;

/// Resting voltage → state of charge (%), typical AGM values.
const _agmCurve = <(double, double)>[
  (11.80, 0),
  (12.00, 25),
  (12.30, 50),
  (12.55, 75),
  (12.85, 100),
];

/// Ohms. Includes cabling; a 230 Ah AGM alone is lower.
const _internalResistance = 0.012;

/// Returns 0–100, or null when no honest estimate is possible.
double? estimateSoc({required double? voltage, required double? current}) {
  if (voltage == null) return null;
  final i = current ?? 0;
  if (i > 0.5) return null; // charging
  final rest = voltage + (-i).clamp(0, double.infinity) * _internalResistance;
  if (rest <= _agmCurve.first.$1) return 0;
  if (rest >= _agmCurve.last.$1) return 100;
  for (var k = 1; k < _agmCurve.length; k++) {
    final (v1, s1) = _agmCurve[k];
    if (rest <= v1) {
      final (v0, s0) = _agmCurve[k - 1];
      return s0 + (rest - v0) / (v1 - v0) * (s1 - s0);
    }
  }
  return 100;
}

/// Hours until the battery reaches 50 %, the floor an AGM should not go
/// below. Null when not discharging or nothing is left above 50 %.
double? hoursTo50({
  required double? soc,
  required double? current,
  required double? capacityAh,
}) {
  if (soc == null || current == null || capacityAh == null) return null;
  if (current > -0.2 || soc <= 50) return null;
  return (soc - 50) / 100 * capacityAh / -current;
}
