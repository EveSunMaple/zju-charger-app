import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/demo_state.dart';

Future<void> showDebugSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x663B342A),
    builder: (context) => const _DebugSheet(),
  );
}

class _DebugSheet extends ConsumerWidget {
  const _DebugSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final notifier = ref.read(demoStateProvider.notifier);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final stationNames = state.snapshot.stations
        .map((station) => station.name)
        .toList(growable: false);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '演示控制',
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
              '模拟定位用于没有 GPS 的环境。距离小于 25m 时，'
              '点云会展开为 2D 俯视。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '模拟定位',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: state.simEnabled,
                  activeTrackColor: AppColors.accent,
                  onChanged: notifier.setSimEnabled,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '距离',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${state.simDistance.round()} m',
                  style: AppText.number.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.dim,
                thumbColor: AppColors.accent,
                overlayColor: const Color(0x1AA26B4A),
                trackHeight: 3,
              ),
              child: Slider(
                value: state.simDistance,
                min: 5,
                max: 3000,
                onChanged: notifier.setSimDistance,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                _PresetChip(
                  label: '200 m',
                  onTap: () => notifier.setSimDistance(200),
                ),
                _PresetChip(
                  label: '50 m',
                  onTap: () => notifier.setSimDistance(50),
                ),
                _PresetChip(
                  label: '10 m',
                  onTap: () => notifier.setSimDistance(10),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: state.target.name,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '目标站点',
                labelStyle: const TextStyle(fontSize: 12, color: AppColors.sub),
                filled: true,
                fillColor: AppColors.dim,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              items: [
                for (final name in stationNames)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (name) {
                if (name != null) notifier.selectStation(name);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                state.mode == SceneMode.topDown
                    ? '当前：2D 俯视 · 精密导航'
                    : '当前：3D 点云',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.card,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
      ),
      backgroundColor: const Color(0x14A26B4A),
      side: const BorderSide(color: Color(0x33A26B4A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
