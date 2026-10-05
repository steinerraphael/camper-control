import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model.dart';
import '../providers.dart';
import 'theme.dart';

/// Scrollable page body below the transparent app bar.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: kToolbarHeight + 4)),
        for (final s in slivers)
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: s),
        SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

/// Renders [builder] once a state is known, a waiting hint until then.
class WithState extends ConsumerWidget {
  const WithState({super.key, required this.builder});

  final Widget Function(BuildContext context, CamperState state) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(camperStateProvider)) {
      AsyncData(:final value) => builder(context, value),
      AsyncError(:final error) => WaitingHint(message: 'Fehler: $error'),
      _ => const WaitingHint(message: 'Warte auf die Steuereinheit …'),
    };
  }
}

class WaitingHint extends ConsumerWidget {
  const WaitingHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.teal),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            const Text(
              'Erreichbar ist sie nur im Camper-WLAN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(pageProvider.notifier).state = AppPage.settings,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Einstellungen'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProtectionBanner extends StatelessWidget {
  const ProtectionBanner({super.key, required this.recoverV});

  final double? recoverV;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: Gradients.bad),
        boxShadow: [
          BoxShadow(color: AppColors.red.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -6),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_alert_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unterspannungsschutz aktiv',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verbraucher wurden abgeschaltet, um die Batterie zu schonen. '
                  'Freigabe ab ${fmt(recoverV, 1)} V, also sobald geladen wird.',
                  style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiles have fixed heights so grids line up; they grow with the phone's
/// text size setting instead of clipping large text.
double textGrow(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.8);
