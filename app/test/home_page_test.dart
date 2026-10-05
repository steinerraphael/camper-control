import 'package:camper_control/main.dart';
import 'package:camper_control/src/api/camper_api.dart';
import 'package:camper_control/src/api/demo_camper_api.dart';
import 'package:camper_control/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DemoCamperApi> pumpApp(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  // A typical phone, so overflow shows up here rather than in the van.
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'mode': 'demo'});
  final prefs = await SharedPreferences.getInstance();
  final api = DemoCamperApi(autoTick: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        apiProvider.overrideWithValue(api),
      ],
      child: const CamperApp(),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> openPage(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Menü'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationDrawer), matching: find.text(title)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('start page shows the connection status and an overview', (tester) async {
    await pumpApp(tester);
    expect(find.text('Verbunden'), findsWidgets);
    expect(find.text('Batterie'), findsOneWidget);
    expect(find.text('0 / 3 an'), findsOneWidget);
  });

  testWidgets('quick access switches from the start page', (tester) async {
    await pumpApp(tester);
    // scrollUntilVisible stops once the chip is built, which can be just
    // below the screen edge; ensureVisible brings it fully into view.
    await tester.ensureVisible(find.text('Wasserhahn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wasserhahn'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3 an'), findsOneWidget);
  });

  testWidgets('menu leads to the switches page, and a tile switches', (tester) async {
    await pumpApp(tester);
    await openPage(tester, 'Schalter');
    await tester.tap(find.text('Wasserhahn'));
    await tester.pumpAndSettle();
    expect(find.text('K3 · An · 4,0 A'), findsOneWidget);
  });

  testWidgets('switches page shows the distributor with free channels', (tester) async {
    await pumpApp(tester);
    await openPage(tester, 'Schalter');
    expect(find.text('Verteiler'), findsOneWidget);
    expect(find.text('8 Kanäle · 3 belegt · 5 frei'), findsOneWidget);
    expect(find.bySemanticsLabel('Kanal 7 frei'), findsOneWidget);
    expect(find.bySemanticsLabel('Kanal 3, Wasserhahn, aus'), findsOneWidget);
  });

  testWidgets('every page renders on a small phone', (tester) async {
    await pumpApp(tester, size: const Size(320, 640));
    for (final page in ['Schalter', 'Energie', 'Klima', 'Einstellungen', 'Start']) {
      await openPage(tester, page);
      expect(tester.takeException(), isNull, reason: page);
    }
  });

  testWidgets('every page copes with large system text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    for (final page in ['Schalter', 'Energie', 'Klima', 'Start']) {
      await openPage(tester, page);
      expect(tester.takeException(), isNull, reason: page);
    }
  });

  testWidgets('protection shows a banner and locked tiles explain themselves', (tester) async {
    final api = await pumpApp(tester);
    api.scenario = DemoScenario.lowBattery;
    for (var i = 0; i <= DemoCamperApi.cutoffDelayS; i++) {
      api.tick();
    }
    await tester.pumpAndSettle();
    expect(find.text('Unterspannungsschutz aktiv'), findsOneWidget);

    await openPage(tester, 'Schalter');
    await tester.tap(find.text('Wasserhahn'));
    await tester.pump();
    expect(find.text(const SwitchLockedException().message), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the demo scenario can be changed in the settings', (tester) async {
    final api = await pumpApp(tester);
    await openPage(tester, 'Einstellungen');
    await tester.tap(find.text('Laden'));
    await tester.pumpAndSettle();
    expect(api.scenario, DemoScenario.charging);
  });
}
