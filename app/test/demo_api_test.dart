import 'package:camper_control/src/api/camper_api.dart';
import 'package:camper_control/src/api/demo_camper_api.dart';
import 'package:camper_control/src/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoCamperApi api;
  setUp(() => api = DemoCamperApi(autoTick: false));
  tearDown(() => api.dispose());

  SwitchState sw(CamperState s, String id) => s.switches.firstWhere((x) => x.id == id);

  test('switching is reflected in the state and in the drawn current', () async {
    final before = (await api.watch().first).batteries.single.current!;
    final after = await api.setSwitch('water_pump', true);
    expect(sw(after, 'water_pump').on, isTrue);
    expect(after.batteries.single.current!, closeTo(before - 4, 0.01));
  });

  test('a flat battery sheds loads after the delay, and charging releases them', () async {
    await api.setSwitch('water_pump', true);
    await api.setSwitch('bed_light', true);
    api.scenario = DemoScenario.lowBattery;

    for (var i = 0; i < DemoCamperApi.cutoffDelayS - 1; i++) {
      api.tick();
    }
    var s = await api.watch().first;
    expect(s.protection.active, isFalse, reason: 'a short dip must not shed');

    api
      ..tick()
      ..tick();
    s = await api.watch().first;
    expect(s.protection.active, isTrue);
    expect(sw(s, 'water_pump').on, isFalse);
    expect(sw(s, 'water_pump').locked, isTrue);
    expect(sw(s, 'bed_light').on, isTrue, reason: 'the bed light has no shed priority');
    expect(() => api.setSwitch('water_pump', true), throwsA(isA<SwitchLockedException>()));

    api
      ..scenario = DemoScenario.charging
      ..tick();
    s = await api.watch().first;
    expect(s.protection.active, isFalse);
    expect(sw(s, 'water_pump').locked, isFalse);
    expect(sw(s, 'water_pump').on, isFalse, reason: 'released, not switched back on');
  });
}
