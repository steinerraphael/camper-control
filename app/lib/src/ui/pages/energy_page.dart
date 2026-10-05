import 'package:flutter/material.dart';

import '../battery_card.dart';
import '../common.dart';
import '../glass.dart';
import '../theme.dart';

class EnergyPage extends StatelessWidget {
  const EnergyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WithState(
      builder: (context, state) {
        final p = state.protection;
        return PageBody(
          slivers: [
            if (p.active)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ProtectionBanner(recoverV: p.recoverV),
                ),
              ),
            for (final b in state.batteries)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: BatteryCard(battery: b),
                ),
              ),
            if (p.enabled) ...[
              const SliverToBoxAdapter(child: SectionTitle('Unterspannungsschutz')),
              SliverToBoxAdapter(
                child: GlassCard(
                  child: Column(
                    children: [
                      _Row(
                        icon: Icons.shield_rounded,
                        color: p.active ? AppColors.red : AppColors.green,
                        label: 'Status',
                        value: p.active ? 'Aktiv – Verbraucher gesperrt' : 'Bereit',
                      ),
                      _Row(
                        icon: Icons.trending_down_rounded,
                        color: AppColors.orange,
                        label: 'Abschalten unter',
                        value: '${fmt(p.cutoffV, 1)} V',
                      ),
                      _Row(
                        icon: Icons.trending_up_rounded,
                        color: AppColors.teal,
                        label: 'Freigabe ab',
                        value: '${fmt(p.recoverV, 1)} V',
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    'Der Ladestand ist aus der Spannung geschätzt. Unter Last und kurz nach dem '
                    'Laden weicht er ab. Eine AGM sollte nicht unter 50 % entladen werden.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
