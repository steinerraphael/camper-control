import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model.dart';
import 'glass.dart';
import 'theme.dart';

class TemperatureCard extends StatelessWidget {
  const TemperatureCard({super.key, required this.sensor, required this.history});

  final SensorState sensor;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final t = sensor.temperature;
    final color = _colorFor(t);
    final isFridge = sensor.id.contains('fridge') || sensor.name.toLowerCase().contains('kühl');

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFridge ? Icons.ac_unit_rounded : Icons.thermostat_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sensor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: fmt(t, 1),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const TextSpan(
                  text: ' °C',
                  style:
                      TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (sensor.error != null)
            Text(sensor.error!, style: const TextStyle(color: AppColors.red, fontSize: 12))
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: CustomPaint(painter: _Sparkline(history, color)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _colorFor(double? t) {
    if (t == null) return AppColors.muted;
    if (t < 8) return AppColors.cyan;
    if (t < 16) return AppColors.blue;
    if (t < 26) return AppColors.teal;
    return AppColors.orange;
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.points, this.color);

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var lo = points.reduce(math.min);
    var hi = points.reduce(math.max);
    // A flat reading should look flat, not like noise blown up to full height.
    if (hi - lo < 1) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.5;
      hi = mid + 0.5;
    }
    final dx = size.width / (points.length - 1);
    Offset at(int i) => Offset(
          i * dx,
          size.height - 2 - (points[i] - lo) / (hi - lo) * (size.height - 4),
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.points != points || old.color != color;
}
