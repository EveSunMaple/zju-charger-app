import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';

class HeroCard extends ConsumerWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final station = state.target;
    final hasFree = station.free > 0;
    final ports = station.ports;
    final strip = ports.take(12).toList(growable: false);
    final remaining = ports.length - strip.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFree ? '最近可用' : '最近站点 · 暂无空闲',
                      style: AppText.heroLabel.copyWith(
                        color: hasFree ? AppColors.accent : AppColors.busy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      station.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heroName,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatDistanceValue(state.distanceToTarget),
                          style: AppText.number.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatDistanceUnit(state.distanceToTarget),
                          style: AppText.small.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '直线 · ${formatEta(state.distanceToTarget)}',
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${station.free}',
                    style: AppText.number.copyWith(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: hasFree ? AppColors.free : AppColors.busy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '空闲插口',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1,
                      color: AppColors.sub,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final port in strip)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: port.kind == PortKind.free
                          ? AppColors.free
                          : AppColors.fault,
                      borderRadius: BorderRadius.circular(4.5),
                    ),
                  ),
                ),
              if (remaining > 0) Text('+$remaining', style: AppText.tiny),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 14,
                child: _HeroButton(
                  primary: true,
                  icon: Icons.near_me_outlined,
                  label: '导航前往',
                  onTap: () => openAmapNavigation(
                    context: context,
                    station: state.target,
                    from: state.myPosition,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 10,
                child: _HeroButton(
                  label: state.refreshing ? '刷新中…' : '刷新数据',
                  onTap: state.refreshing
                      ? null
                      : () async {
                          final updated = await ref
                              .read(demoStateProvider.notifier)
                              .refresh();
                          if (!context.mounted) return;
                          final message = updated
                              ? '数据已更新'
                              : (state.snapshot.source == 'api'
                                    ? '刷新失败，请检查后端服务'
                                    : '演示快照无需刷新，数据未变化');
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              if (state.refreshing) ...[
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  state.refreshing
                      ? '正在同步数据…'
                      : (state.snapshot.source == 'api'
                            ? '实时数据 · 来自校园充电桩网关'
                            : '演示快照 · 数据来自离线文件'),
                  style: AppText.tiny,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = primary ? AppColors.card : AppColors.text;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: primary ? AppColors.accent : AppColors.dim,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: primary ? null : Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
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
