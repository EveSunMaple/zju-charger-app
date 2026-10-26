import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';
import 'nearby_list.dart';
import 'radar_painter.dart';

class RadarCard extends ConsumerWidget {
  const RadarCard({super.key, required this.onSelect});

  final ValueChanged<Station> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final positions = state.positions;

    void select(Station station) {
      ref.read(demoStateProvider.notifier).selectStation(station.name);
      onSelect(station);
    }

    final radar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final station = radarHitTest(
          details.localPosition,
          positions,
        );
        if (station != null) select(station);
      },
      child: SizedBox(
        width: radarSize,
        height: radarSize,
        child: CustomPaint(
          painter: RadarPainter(
            positions: positions,
            targetName: state.target.name,
          ),
        ),
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 420) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    radar,
                    const SizedBox(height: 4),
                    const Text(
                      '对数刻度 · 点按站点切换',
                      style: AppText.tiny,
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: NearbyList(
                    positions: positions,
                    targetName: state.target.name,
                    onSelect: select,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: radar),
              const SizedBox(height: 4),
              const Center(
                child: Text('对数刻度 · 点按站点切换', style: AppText.tiny),
              ),
              const SizedBox(height: 10),
              NearbyList(
                positions: positions,
                targetName: state.target.name,
                onSelect: select,
              ),
            ],
          );
        },
      ),
    );
  }
}
