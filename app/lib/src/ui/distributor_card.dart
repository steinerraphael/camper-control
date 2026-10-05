import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model.dart';
import 'glass.dart';
import 'switch_tile.dart';
import 'theme.dart';

/// The relay module at a glance: every channel, which circuit it carries,
/// whether it is on, and which ones are still free for the next circuit.
class DistributorCard extends StatelessWidget {
  const DistributorCard({super.key, required this.channels, required this.switches});

  final int channels;
  final List<SwitchState> switches;

  @override
  Widget build(BuildContext context) {
    final byChannel = {
      for (final s in switches)
        if (s.channel != null) s.channel!: s,
    };
    final used = byChannel.length;
    final on = byChannel.values.where((s) => s.on).length;
    final buttons = byChannel.values.where((s) => s.button).length;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.developer_board_rounded, color: AppColors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verteiler',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '$channels Kanäle · $used belegt · ${channels - used} frei',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(
                on == 0 ? 'alles aus' : '$on an',
                style: TextStyle(
                  color: on == 0 ? AppColors.muted : AppColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 6.0;
              final perRow = math.min(channels, 8);
              final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var ch = 1; ch <= channels; ch++)
                    _ChannelCell(channel: ch, sw: byChannel[ch], width: width),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            buttons == 0
                ? 'Schalten nur über die App.'
                : buttons == used
                    ? 'Alle belegten Kanäle haben zusätzlich einen Taster.'
                    : '$buttons von $used Kanälen haben zusätzlich einen Taster.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChannelCell extends StatelessWidget {
  const _ChannelCell({required this.channel, required this.sw, required this.width});

  final int channel;
  final SwitchState? sw;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = sw;
    final color = s == null ? AppColors.muted : switchLook(s.id).$2;
    final on = s?.on ?? false;
    final locked = s?.locked ?? false;

    final label = s == null
        ? 'Kanal $channel frei'
        : 'Kanal $channel, ${s.name}, ${locked ? 'gesperrt' : on ? 'an' : 'aus'}';

    // One label per cell instead of "7" and an icon read out separately.
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: width,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: on ? color : (s == null ? Colors.transparent : color.withValues(alpha: 0.12)),
          border: Border.all(
            color: locked
                ? AppColors.red
                : on
                    ? color
                    : (s == null ? AppColors.glassBorder : color.withValues(alpha: 0.35)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$channel',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: on ? AppColors.bg0 : (s == null ? AppColors.muted : AppColors.text),
              ),
            ),
            Icon(
              s == null
                  ? Icons.remove_rounded
                  : locked
                      ? Icons.lock_rounded
                      : switchLook(s.id).$1,
              size: 12,
              color: on ? AppColors.bg0 : (locked ? AppColors.red : color),
            ),
          ],
        ),
      ),
    );
  }
}
