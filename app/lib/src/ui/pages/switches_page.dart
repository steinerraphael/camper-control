import 'package:flutter/material.dart';

import '../common.dart';
import '../distributor_card.dart';
import '../glass.dart';
import '../switch_tile.dart';
import '../theme.dart';

class SwitchesPage extends StatelessWidget {
  const SwitchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WithState(
      builder: (context, state) {
        final active = state.switches.where((s) => s.on).length;
        return PageBody(
          slivers: [
            if (state.protection.active)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ProtectionBanner(recoverV: state.protection.recoverV),
                ),
              ),
            if (state.distributorChannels != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DistributorCard(
                    channels: state.distributorChannels!,
                    switches: state.switches,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SectionTitle(
                'Verbraucher',
                trailing: Text(
                  active == 0 ? 'alles aus' : '$active an',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 138 * textGrow(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => SwitchTile(sw: state.switches[i]),
                childCount: state.switches.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
