import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';
import '../../state/preferences_state.dart';
import '../../state/reminder_service.dart';
import '../favorites/favorites_sheet.dart';

class HeroCard extends ConsumerWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final station = state.target;
    final hasFree = station.free > 0;
    final prefs = ref.watch(stationPrefsProvider);
    final favorite = prefs.favorites.contains(station.name);
    final reminder = prefs.reminders.contains(station.name);
    final reminderService = ref.watch(reminderServiceProvider);
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
                          final notifier = ref.read(demoStateProvider.notifier);
                          final updated = state.snapshot.source == 'api'
                              ? await notifier.refreshStation()
                              : await notifier.refresh();
                          if (!context.mounted) return;
                          final message = updated
                              ? (state.snapshot.source == 'api'
                                    ? '当前站数据已刷新'
                                    : '数据已更新')
                              : (state.snapshot.source == 'api'
                                    ? '刷新失败，请稍后重试'
                                    : '演示快照无需刷新，数据未变化');
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PrefChip(
                icon: favorite ? Icons.star : Icons.star_border,
                label: favorite ? '已收藏' : '收藏',
                active: favorite,
                onTap: () async {
                  final added = await ref
                      .read(stationPrefsProvider.notifier)
                      .toggleFavorite(station.name);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(added ? '已加入本地收藏' : '已取消收藏')),
                  );
                },
              ),
              const SizedBox(width: 8),
              _PrefChip(
                icon: reminder
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                label: reminder ? '提醒已开' : '空位提醒',
                active: reminder,
                enabled: reminderService.available || reminder,
                onTap: () async {
                  if (!reminderService.available && !reminder) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('推送未配置，暂时无法开启空位提醒')),
                    );
                    return;
                  }
                  final added = await ref
                      .read(stationPrefsProvider.notifier)
                      .toggleReminder(station.name);
                  final synced = await reminderService.sync(
                    ref.read(stationPrefsProvider).reminders,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        synced
                            ? (added ? '已开启该站空位提醒' : '已关闭该站空位提醒')
                            : '提醒已保存，但同步服务器失败',
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showFavoritesSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                icon: const Icon(Icons.bookmark_border, size: 16),
                label: const Text(
                  '收藏夹',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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
                            ? '实时数据 · 本桩 '
                                  '${formatAge(state.target.observedAt ?? state.snapshot.fetchedAt)}'
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

class _PrefChip extends StatelessWidget {
  const _PrefChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: active ? const Color(0x1AA26B4A) : AppColors.dim,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? const Color(0x33A26B4A) : AppColors.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? AppColors.accent : AppColors.sub,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.accent : AppColors.sub,
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
