import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battery.dart';
import '../model.dart';
import 'glass.dart';
import 'theme.dart';

class BatteryCard extends StatelessWidget {
  const BatteryCard({super.key, required this.battery});

  final SensorState battery;

  @override
  Widget build(BuildContext context) {
    final v = battery.voltage;
    final i = battery.current;
    final charging = (i ?? 0) > 0.5;
    final soc = estimateSoc(voltage: v, current: i);
    final hours = hoursTo50(soc: soc, current: i, capacityAh: battery.capacityAh);
    // While charging there is no SoC; the ring shows the charge voltage instead.
    final fraction = soc != null ? soc / 100 : ((v ?? 12) - 11.8) / (14.4 - 11.8);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.battery_charging_full_rounded, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  battery.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
              if (battery.capacityAh != null)
                Text(
                  'AGM ${battery.capacityAh!.round()} Ah',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final ringSize = math.min(160.0, c.maxWidth * 0.46);
              return Row(
                children: [
                  _Ring(
                    size: ringSize,
                    fraction: fraction.clamp(0, 1).toDouble(),
                    color: charging ? AppColors.green : _socColor(soc),
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmt(v, 2),
                          style: TextStyle(
                            fontSize: ringSize * 0.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text('Volt', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 6),
                        _SocBadge(soc: soc, charging: charging),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stat(
                          icon: charging ? Icons.south_rounded : Icons.north_rounded,
                          color: charging ? AppColors.green : AppColors.amber,
                          label: charging ? 'Ladestrom' : 'Entnahme',
                          value: '${fmt(i?.abs(), 1)} A',
                        ),
                        _Stat(
                          icon: Icons.bolt_rounded,
                          color: AppColors.cyan,
                          label: 'Leistung',
                          value: '${fmt(battery.power?.abs(), 0)} W',
                        ),
                        _Stat(
                          icon: Icons.schedule_rounded,
                          color: AppColors.violet,
                          label: 'Bis 50 %',
                          value: charging
                              ? 'lädt'
                              : hours == null
                                  ? '–'
                                  : hours >= 99
                                      ? '> 99 h'
                                      : '≈ ${fmt(hours, hours < 10 ? 1 : 0)} h',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (battery.error != null) ...[
            const SizedBox(height: 12),
            Text(battery.error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  static Color _socColor(double? soc) {
    if (soc == null) return AppColors.muted;
    if (soc < 50) return AppColors.red;
    if (soc < 70) return AppColors.amber;
    return AppColors.teal;
  }
}

class _SocBadge extends StatelessWidget {
  const _SocBadge({required this.soc, required this.charging});

  final double? soc;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final text = charging
        ? 'lädt'
        : soc == null
            ? '–'
            : '≈ ${soc!.round()} %';
    return Tooltip(
      message: 'Schätzung aus der Spannung (AGM)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

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
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.fraction,
    required this.color,
    required this.center,
  });

  final double size;
  final double fraction;
  final Color color;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 500),
        builder: (context, c, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(value, c ?? color),
          child: SizedBox.square(
            dimension: size,
            // Large system text shrinks to fit inside the ring rather than spilling out.
            child: Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
      child: center,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 4);

    canvas.drawArc(
      arcRect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x14FFFFFF),
    );
    if (fraction <= 0) return;

    final sweep = _sweep * fraction;
    // The arc crosses angle 0, so the gradient is rotated rather than given
    // start/end angles past 2π, which would clamp the tail to one colour.
    final gradient = SweepGradient(
      endAngle: _sweep,
      transform: const GradientRotation(_start),
      colors: [color.withValues(alpha: 0.35), color],
      tileMode: TileMode.clamp,
    ).createShader(rect);

    // Soft glow under the arc.
    canvas.drawArc(
      arcRect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawArc(
      arcRect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
