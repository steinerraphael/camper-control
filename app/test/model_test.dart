import 'dart:convert';
import 'dart:io';

import 'package:camper_control/src/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the snapshot the controller actually sends', () {
    // Written by the backend test suite (tests/test_contract.py), so a change
    // to the controller's output shows up here instead of on the phone.
    final json = jsonDecode(File('test/fixtures/state.json').readAsStringSync());
    final state = CamperState.fromJson(json as Map<String, dynamic>);

    expect(state.switches.map((s) => s.id), contains('water_pump'));
    final pump = state.switches.firstWhere((s) => s.id == 'water_pump');
    expect(pump.name, 'Wasserpumpe');
    expect(pump.loadA, 4.0);
    expect(pump.channel, 3);
    expect(pump.button, isTrue);
    expect(state.distributorChannels, 8);

    final battery = state.batteries.single;
    expect(battery.voltage, isNotNull);
    expect(battery.capacityAh, 230);
    expect(state.thermometers, hasLength(2));
    expect(state.protection.enabled, isTrue);
    expect(state.protection.cutoffV, 12.0);
  });

  test('unknown or missing fields fall back instead of throwing', () {
    final state = CamperState.fromJson({
      'switches': [
        {'id': 'x', 'on': 'yes', 'shiny_new_field': 1},
      ],
      'sensors': [
        {
          'id': 'y',
          'type': 'bme280',
          'values': {'humidity': 40, 'bad': 'n/a'}
        },
      ],
    });
    expect(state.switches.single.on, isFalse);
    expect(state.switches.single.name, 'x');
    expect(state.sensors.single.kind, SensorKind.unknown);
    expect(state.sensors.single.values, {'humidity': 40.0});
    expect(state.protection.active, isFalse);
  });
}
