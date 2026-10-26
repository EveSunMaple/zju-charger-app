import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/demo_state.dart';
import 'precise_panel.dart';
import 'scene_model.dart';
import 'scene_painter.dart';

class SceneCard extends ConsumerStatefulWidget {
  const SceneCard({super.key});

  @override
  ConsumerState<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends ConsumerState<SceneCard>
    with TickerProviderStateMixin {
  late final AnimationController _morph;
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);

  SceneModel? _model;
  String _modelKey = '';
  double _target = 0;

  @override
  void initState() {
    super.initState();
    final state = ref.read(demoStateProvider);
    _target = state.mode == SceneMode.topDown ? 1 : 0;
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: _target,
    );
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1000000;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _morph.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoStateProvider);
    ref.listen<DemoState>(demoStateProvider, (previous, next) {
      final target = next.mode == SceneMode.topDown ? 1.0 : 0.0;
      if (target == _target) return;
      _target = target;
      _morph.animateTo(
        target,
        duration: const Duration(milliseconds: 1400),
        curve: Curves.linear,
      );
    });

    final key =
        '${state.target.name}|${state.snapshot.fetchedAt.toIso8601String()}';
    if (key != _modelKey) {
      _modelKey = key;
      _model = buildSceneModel(state.target);
    }

    final station = state.target;
    final isTopDown = state.mode == SceneMode.topDown;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  station.campusName.isEmpty
                      ? station.name
                      : '${station.name} · ${station.campusName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle,
                ),
              ),
              const SizedBox(width: 8),
              _DistanceChip(text: formatDistance(state.distanceToTarget)),
              const SizedBox(width: 8),
              const _Legend(),
            ],
          ),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: SizedBox(
              height: 330,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppColors.card2),
                    if (_model != null)
                      CustomPaint(
                        painter: ScenePainter(
                          model: _model!,
                          modeT: _morph,
                          clock: _clock,
                          bearingToTarget: state.bearingToTarget,
                          stationName: station.name,
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _ModeBadge(topDown: isTopDown),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isTopDown
                ? const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: PrecisePanel(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1AA26B4A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.topDown});

  final bool topDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6FBF8F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: topDown ? const Color(0x59A26B4A) : AppColors.line,
        ),
      ),
      child: Text(
        topDown ? '2D 俯视 · 精密导航' : '3D 点云',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: topDown ? AppColors.accent : AppColors.sub,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _LegendItem(color: AppColors.free, label: '空闲'),
        SizedBox(width: 6),
        _LegendItem(color: AppColors.busy, label: '占用'),
        SizedBox(width: 6),
        _LegendItem(color: AppColors.fault, label: '故障'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: AppText.tiny.copyWith(fontSize: 9.5)),
      ],
    );
  }
}
