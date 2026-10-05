import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'theme.dart';

/// What the start page, the menu and the pill in the app bar all show.
class ConnectionStatus {
  const ConnectionStatus._(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.gradient, {
    this.connected = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final bool connected;
}

final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.mode == ConnectionMode.demo) {
    return const ConnectionStatus._(
      'Verbunden',
      'mit der Demo-Simulation · nichts wird wirklich geschaltet',
      Icons.check_circle_rounded,
      AppColors.violet,
      Gradients.demo,
    );
  }
  final connected = ref.watch(connectedProvider).valueOrNull ?? false;
  final host = Uri.tryParse(settings.baseUrl)?.authority ?? settings.baseUrl;
  return connected
      ? ConnectionStatus._(
          'Verbunden',
          'mit der Steuereinheit · $host',
          Icons.check_circle_rounded,
          AppColors.green,
          Gradients.ok,
        )
      : ConnectionStatus._(
          'Nicht verbunden',
          '$host nicht erreichbar · neuer Versuch läuft',
          Icons.wifi_off_rounded,
          AppColors.red,
          Gradients.bad,
          connected: false,
        );
});

/// Compact status in the app bar: a dot and one word.
class StatusPill extends ConsumerWidget {
  const StatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(settingsProvider).mode == ConnectionMode.demo;
    final status = ref.watch(connectionStatusProvider);
    final label = demo ? 'Demo' : (status.connected ? 'Live' : 'Offline');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: status.color, pulsing: !demo && status.connected),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: status.color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, required this.pulsing, this.size = 8});

  final Color color;
  final bool pulsing;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.pulsing) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: (1 - _c.value) * 0.8),
              blurRadius: 2,
              spreadRadius: _c.value * widget.size * 0.75,
            ),
          ],
        ),
      ),
    );
  }
}
