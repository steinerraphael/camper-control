import '../model.dart';

/// Everything the UI needs from a controller, real or simulated.
abstract class CamperApi {
  /// The current state first (once known), then every change.
  Stream<CamperState> watch();

  /// Whether the controller is currently reachable.
  Stream<bool> get connection;

  /// Switches and returns the resulting state.
  ///
  /// Throws [SwitchLockedException] when low-voltage protection holds the
  /// switch off, [ApiException] for anything else.
  Future<CamperState> setSwitch(String id, bool on);

  void dispose();
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SwitchLockedException extends ApiException {
  const SwitchLockedException()
      : super('Gesperrt durch den Unterspannungsschutz, '
            'bis die Batterie wieder geladen wird.');
}
