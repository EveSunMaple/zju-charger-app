import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/demo_state.dart';
import '../../state/preferences_state.dart';
import '../../state/reminder_service.dart';

Future<void> showFavoritesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x663B342A),
    builder: (context) => const _FavoritesSheet(),
  );
}

class _FavoritesSheet extends ConsumerWidget {
  const _FavoritesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final prefs = ref.watch(stationPrefsProvider);
    final reminderService = ref.watch(reminderServiceProvider);
    final positions = state.positions;
    final byName = {for (final item in positions) item.station.name: item};
    final stations = prefs.favorites
        .map((name) => byName[name])
        .whereType<StationDistance>()
        .toList(growable: false);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '收藏夹',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.sub,
              ),
            ],
          ),
          const Text(
            '收藏和空位提醒只保存在当前设备，不需要登录。',
            style: TextStyle(fontSize: 11.5, color: AppColors.sub),
          ),
          const SizedBox(height: 12),
          if (stations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                '还没有收藏站点\n在当前站点卡片点「收藏」即可加入',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.sub,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: stations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = stations[index];
                  final reminder = prefs.reminders.contains(item.station.name);
                  return _FavoriteRow(
                    item: item,
                    reminder: reminder,
                    reminderAvailable: reminderService.available || reminder,
                    onSelect: () {
                      ref
                          .read(demoStateProvider.notifier)
                          .selectStation(item.station.name);
                      Navigator.of(context).pop();
                    },
                    onRemove: () async {
                      await ref
                          .read(stationPrefsProvider.notifier)
                          .toggleFavorite(item.station.name);
                    },
                    onToggleReminder: () async {
                      if (!reminderService.available && !reminder) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('推送未配置，暂时无法开启空位提醒')),
                        );
                        return;
                      }
                      await ref
                          .read(stationPrefsProvider.notifier)
                          .toggleReminder(item.station.name);
                      await reminderService.sync(
                        ref.read(stationPrefsProvider).reminders,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.item,
    required this.reminder,
    required this.reminderAvailable,
    required this.onSelect,
    required this.onRemove,
    required this.onToggleReminder,
  });

  final StationDistance item;
  final bool reminder;
  final bool reminderAvailable;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final VoidCallback onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final station = item.station;
    return Material(
      color: AppColors.dim,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDistance(item.distance)} · 空闲 ${station.free}/${station.total}',
                      style: AppText.tiny,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: reminder ? '关闭空位提醒' : '开启空位提醒',
                onPressed: reminderAvailable ? onToggleReminder : null,
                icon: Icon(
                  reminder
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 18,
                  color: reminder ? AppColors.accent : AppColors.sub,
                ),
              ),
              IconButton(
                tooltip: '取消收藏',
                onPressed: onRemove,
                icon: const Icon(Icons.star, size: 18, color: AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
