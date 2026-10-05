import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/camper_api.dart';
import '../../battery.dart';
import '../../model.dart';
import '../../providers.dart';
import '../common.dart';
import '../glass.dart';
import '../status.dart';
import '../switch_tile.dart';
import '../theme.dart';

class StartPage extends ConsumerWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(camperStateProvider).valueOrNull;

    return PageBody(
      slivers: [
        const SliverToBoxAdapter(child: _StatusHero()),
        if (state != null) ...[
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: state.protection.active
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: ProtectionBanner(recoverV: state.protection.recoverV),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          const SliverToBoxAdapter(child: SectionTitle('Überblick')),
          _Summary(state: state),
          const SliverToBoxAdapter(child: SectionTitle('Schnellzugriff')),
          SliverToBoxAdapter(child: _QuickSwitches(switches: state.switches)),
        ],
      ],
    );
  }
}

class _StatusHero extends ConsumerWidget {
  const _StatusHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final updated = ref.watch(lastUpdateProvider);
    // Pulses only for a real link; the demo has nothing alive to signal.
    final live = ref.watch(settingsProvider).mode == ConnectionMode.live;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: status.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: status.gradient.first.withValues(alpha: 0.45),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                child: Icon(status.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      status.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              PulseDot(color: Colors.white, pulsing: live && status.connected, size: 10),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            status.subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
          ),
          if (updated != null) ...[
            const SizedBox(height: 4),
            Text(
              'Zuletzt aktualisiert ${_time(updated)}',
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5),
            ),
          ],
          if (!status.connected) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.bg0,
              ),
              onPressed: () => ref.read(pageProvider.notifier).state = AppPage.settings,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Verbindung einstellen'),
            ),
          ],
        ],
      ),
    );
  }

  static String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)} Uhr';

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.state});

  final CamperState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(AppPage p) => ref.read(pageProvider.notifier).state = p;

    final battery = state.batteries.firstOrNull;
    final soc = estimateSoc(voltage: battery?.voltage, current: battery?.current);
    final charging = (battery?.current ?? 0) > 0.5;
    final on = state.switches.where((s) => s.on).toList();
    final load = on.fold(0.0, (a, s) => a + s.loadA);
    final temps = state.thermometers.take(2).toList();

    final tiles = [
      if (battery != null)
        _SummaryTile(
          accent: soc != null && soc < 50 ? AppColors.red : AppColors.green,
          icon: charging ? Icons.battery_charging_full_rounded : Icons.battery_5_bar_rounded,
          label: 'Batterie',
          value: charging ? 'lädt' : (soc == null ? '–' : '≈ ${soc.round()} %'),
          detail: '${fmt(battery.voltage, 2)} V',
          onTap: () => go(AppPage.energy),
        ),
      _SummaryTile(
        accent: AppColors.amber,
        icon: Icons.power_rounded,
        label: 'Verbraucher',
        value: '${on.length} / ${state.switches.length} an',
        detail: on.isEmpty ? 'alles aus' : '${fmt(load, 1)} A',
        onTap: () => go(AppPage.switches),
      ),
      for (final t in temps)
        _SummaryTile(
          accent: (t.temperature ?? 20) < 10 ? AppColors.cyan : AppColors.teal,
          icon: (t.temperature ?? 20) < 10 ? Icons.ac_unit_rounded : Icons.thermostat_rounded,
          label: t.name,
          value: '${fmt(t.temperature, 1)} °C',
          detail: t.error ?? 'Temperatur',
          onTap: () => go(AppPage.climate),
        ),
    ];

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 142 * textGrow(context),
      ),
      delegate: SliverChildListDelegate(tiles),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x14FFFFFF), AppColors.glass],
          ),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.16),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-tap chips for the circuits used most, without leaving the start page.
class _QuickSwitches extends ConsumerWidget {
  const _QuickSwitches({required this.switches});

  final List<SwitchState> switches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final sw in switches)
          _QuickChip(
            sw: sw,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              HapticFeedback.lightImpact();
              try {
                await ref.read(apiProvider).setSwitch(sw.id, !sw.on);
              } on ApiException catch (e) {
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.sw, required this.onTap});

  final SwitchState sw;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switchLook(sw.id);
    return Semantics(
      button: true,
      toggled: sw.on,
      label: sw.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: sw.on ? color : AppColors.glass,
            border: Border.all(color: sw.on ? color : AppColors.glassBorder),
            boxShadow: sw.on
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -4)]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sw.locked ? Icons.lock_rounded : icon,
                size: 18,
                color: sw.on ? AppColors.bg0 : color,
              ),
              const SizedBox(width: 6),
              Text(
                sw.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: sw.on ? AppColors.bg0 : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
