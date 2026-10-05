import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'glass.dart';
import 'pages/climate_page.dart';
import 'pages/energy_page.dart';
import 'pages/settings_page.dart';
import 'pages/start_page.dart';
import 'pages/switches_page.dart';
import 'status.dart';
import 'theme.dart';

extension AppPageLook on AppPage {
  String get title => switch (this) {
        AppPage.start => 'Camper',
        AppPage.switches => 'Schalter',
        AppPage.energy => 'Energie',
        AppPage.climate => 'Klima',
        AppPage.settings => 'Einstellungen',
      };

  IconData get icon => switch (this) {
        AppPage.start => Icons.home_rounded,
        AppPage.switches => Icons.toggle_on_rounded,
        AppPage.energy => Icons.battery_charging_full_rounded,
        AppPage.climate => Icons.thermostat_rounded,
        AppPage.settings => Icons.tune_rounded,
      };

  Color get color => switch (this) {
        AppPage.start => AppColors.teal,
        AppPage.switches => AppColors.amber,
        AppPage.energy => AppColors.green,
        AppPage.climate => AppColors.pink,
        AppPage.settings => AppColors.violet,
      };
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(pageProvider);

    // Android back from a sub page goes to the start page, not out of the app.
    return PopScope(
      canPop: page == AppPage.start,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(pageProvider.notifier).state = AppPage.start;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        // The drawer has a fixed width; very large text would not fit in it.
        drawer: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, child: const _Menu()),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleSpacing: 4,
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Menü',
              icon: const Icon(Icons.menu_rounded, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            page.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          actions: const [Padding(padding: EdgeInsets.only(right: 12), child: StatusPill())],
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: Backdrop()),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  // Phone first; on a tablet it stays phone-shaped.
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(page),
                      child: switch (page) {
                        AppPage.start => const StartPage(),
                        AppPage.switches => const SwitchesPage(),
                        AppPage.energy => const EnergyPage(),
                        AppPage.climate => const ClimatePage(),
                        AppPage.settings => const SettingsPage(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(pageProvider);
    final status = ref.watch(connectionStatusProvider);

    return NavigationDrawer(
      backgroundColor: AppColors.bg1,
      indicatorColor: page.color.withValues(alpha: 0.18),
      selectedIndex: page.index,
      onDestinationSelected: (i) {
        ref.read(pageProvider.notifier).state = AppPage.values[i];
        Navigator.of(context).pop();
      },
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0EA5A4), Color(0xFF6366F1), Color(0xFFEC4899)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.airport_shuttle_rounded, size: 36, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                'Camper Control',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Text('VW T5', style: TextStyle(color: Color(0xDDFFFFFF))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(status.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    status.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final p in AppPage.values)
          NavigationDrawerDestination(
            icon: Icon(p.icon, color: p.color),
            label: Text(p.title == 'Camper' ? 'Start' : p.title),
          ),
      ],
    );
  }
}
