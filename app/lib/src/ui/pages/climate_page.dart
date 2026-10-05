import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../common.dart';
import '../glass.dart';
import '../temperature_card.dart';

class ClimatePage extends ConsumerWidget {
  const ClimatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(temperatureHistoryProvider);
    return WithState(
      builder: (context, state) {
        final temps = state.thermometers.toList();
        return PageBody(
          slivers: [
            const SliverToBoxAdapter(child: SectionTitle('Temperaturen')),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 140 * textGrow(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => TemperatureCard(
                  sensor: temps[i],
                  history: history[temps[i].id] ?? const [],
                ),
                childCount: temps.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
