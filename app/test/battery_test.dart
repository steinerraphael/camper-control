import 'package:camper_control/src/battery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateSoc (AGM)', () {
    test('full and empty ends of the curve', () {
      expect(estimateSoc(voltage: 12.9, current: 0), 100);
      expect(estimateSoc(voltage: 11.7, current: 0), 0);
    });

    test('12.3 V at rest is about half', () {
      expect(estimateSoc(voltage: 12.3, current: 0), closeTo(50, 0.01));
    });

    test('voltage sag under load is compensated', () {
      final atRest = estimateSoc(voltage: 12.3, current: 0)!;
      final underLoad = estimateSoc(voltage: 12.3, current: -10)!;
      expect(underLoad, greaterThan(atRest));
    });

    test('no estimate while charging or without a reading', () {
      expect(estimateSoc(voltage: 13.9, current: 20), isNull);
      expect(estimateSoc(voltage: null, current: 0), isNull);
    });
  });

  group('hoursTo50', () {
    test('230 Ah at 80 % and 5 A drawn lasts about 13.8 h', () {
      expect(hoursTo50(soc: 80, current: -5, capacityAh: 230), closeTo(13.8, 0.01));
    });

    test('nothing to report when charging or already at the floor', () {
      expect(hoursTo50(soc: 80, current: 3, capacityAh: 230), isNull);
      expect(hoursTo50(soc: 45, current: -5, capacityAh: 230), isNull);
    });
  });
}
