import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/demo_state.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final snapshot = state.snapshot;
    final stale = isSnapshotStale(snapshot.fetchedAt);
    final statusText = state.simEnabled ? '模拟定位' : '演示位置';
    final statusColor = state.simEnabled ? AppColors.warn : AppColors.fault;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.bolt, size: 15, color: AppColors.card),
          ),
          const SizedBox(width: 8),
          const Text(
            '浙大充电桩',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(statusText, style: AppText.small),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: AppText.small),
              ),
              Text(
                '内置快照 ${formatSnapshotTime(snapshot.fetchedAt)} · '
                '${formatAge(snapshot.fetchedAt)}',
                style: AppText.small.copyWith(
                  color: stale ? AppColors.warn : AppColors.sub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
