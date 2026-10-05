import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/camper_api.dart';
import '../model.dart';
import '../providers.dart';
import 'theme.dart';

/// Icon and colour by what the id says the circuit is. The config names
/// circuits freely, so this guesses and falls back to a power symbol.
(IconData, Color) switchLook(String id) {
  final s = id.toLowerCase();
  if (s.contains('read')) return (Icons.auto_stories_rounded, AppColors.amber);
  if (s.contains('light') || s.contains('licht') || s.contains('lamp')) {
    return (Icons.lightbulb_rounded, AppColors.amber);
  }
  if (s.contains('pump') || s.contains('water') || s.contains('wasser')) {
    return (Icons.water_drop_rounded, AppColors.blue);
  }
  if (s.contains('fridge') || s.contains('kühl') || s.contains('cool')) {
    return (Icons.kitchen_rounded, AppColors.cyan);
  }
  if (s.contains('usb') || s.contains('socket') || s.contains('steckdose')) {
    return (Icons.usb_rounded, AppColors.violet);
  }
  if (s.contains('fan') || s.contains('lüft') || s.contains('vent')) {
    return (Icons.air_rounded, AppColors.teal);
  }
  if (s.contains('heat') || s.contains('heiz')) {
    return (Icons.local_fire_department_rounded, AppColors.orange);
  }
  return (Icons.power_settings_new_rounded, AppColors.green);
}

class SwitchTile extends ConsumerStatefulWidget {
  const SwitchTile({super.key, required this.sw});

  final SwitchState sw;

  @override
  ConsumerState<SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends ConsumerState<SwitchTile> {
  bool _busy = false;

  Future<void> _toggle() async {
    final sw = widget.sw;
    final messenger = ScaffoldMessenger.of(context);
    if (sw.locked) {
      HapticFeedback.heavyImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(const SwitchLockedException().message)));
      return;
    }
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setSwitch(sw.id, !sw.on);
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = widget.sw;
    final (icon, color) = switchLook(sw.id);
    final on = sw.on;

    final status = sw.locked
        ? 'Gesperrt'
        : on
            ? (sw.loadA > 0 ? 'An · ${fmt(sw.loadA, 1)} A' : 'An')
            : 'Aus';

    return Semantics(
      button: true,
      toggled: on,
      enabled: !sw.locked,
      label: sw.name,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: on
                  ? [color.withValues(alpha: 0.30), color.withValues(alpha: 0.08)]
                  : const [Color(0x12FFFFFF), Color(0x08FFFFFF)],
            ),
            border: Border.all(
              color: on ? color.withValues(alpha: 0.6) : color.withValues(alpha: 0.18),
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.28), blurRadius: 24, spreadRadius: -6)
                  ]
                : const [],
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: sw.locked ? 0.5 : (_busy ? 0.7 : 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? color : color.withValues(alpha: 0.16),
                      ),
                      child: Icon(icon, size: 22, color: on ? AppColors.bg0 : color),
                    ),
                    const Spacer(),
                    if (sw.locked)
                      const Icon(Icons.lock_rounded, size: 18, color: AppColors.red)
                    else
                      _Pill(on: on, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  sw.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.15),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: sw.locked ? AppColors.red : (on ? color : AppColors.muted),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small on/off indicator in the corner of the tile.
class _Pill extends StatelessWidget {
  const _Pill({required this.on, required this.color});

  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 38,
      height: 22,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: on ? color.withValues(alpha: 0.9) : const Color(0x22FFFFFF),
      ),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppColors.bg0 : AppColors.muted,
        ),
      ),
    );
  }
}
