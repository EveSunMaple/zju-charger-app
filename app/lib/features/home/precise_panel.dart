import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';

class PrecisePanel extends ConsumerWidget {
  const PrecisePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoStateProvider);
    final station = state.target;
    final free = station.free;
    final hasFree = free > 0;
    final powerItems = _collectPower(station);
    final picked = _pickPower(powerItems);
    final totalWatts = powerItems.fold<double>(
      0,
      (sum, item) => sum + item.power.w,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Compass(bearing: state.bearingToTarget),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatDistanceValue(state.distanceToTarget),
                        style: AppText.number.copyWith(
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatDistanceUnit(state.distanceToTarget),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '按箭头方向前进 · 演示方位',
                    style: TextStyle(fontSize: 11.5, color: AppColors.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: hasFree ? const Color(0x145C875C) : const Color(0x12BC5A4C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFree
                  ? const Color(0x385C875C)
                  : const Color(0x38BC5A4C),
            ),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.text,
              ),
              children: hasFree
                  ? [
                      const TextSpan(text: '本桩 '),
                      TextSpan(
                        text: '$free',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.free,
                        ),
                      ),
                      const TextSpan(text: ' 个插口空闲 · 绿色方块即可用插口'),
                    ]
                  : [
                      const TextSpan(text: '该桩'),
                      const TextSpan(
                        text: '暂无空闲插口',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.busy,
                        ),
                      ),
                      if (station.fault > 0)
                        TextSpan(text: ' · ${station.fault} 个故障'),
                    ],
            ),
          ),
        ),
        if (picked.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            '实时功率 · ${powerItems.length} 口在充 · '
            '合计 ${(totalWatts / 1000).toStringAsFixed(1)}kW',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in picked)
                _PowerChip(
                  label: _powerLabel(station, item),
                  power: item.power,
                  soon: item.kind == PortKind.float || item.power.w < 40,
                ),
              if (powerItems.length > picked.length)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${powerItems.length - picked.length} 口',
                    style: const TextStyle(fontSize: 11, color: AppColors.sub),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 11),
        Material(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => openAmapNavigation(
              context: context,
              station: station,
              from: state.myPosition,
            ),
            child: const SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation_outlined,
                    size: 17,
                    color: AppColors.card,
                  ),
                  SizedBox(width: 7),
                  Text(
                    '打开地图精确导航',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.card,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_PowerItem> _collectPower(Station station) {
    final items = <_PowerItem>[];
    for (final device in station.devices) {
      if (device.offline) continue;
      for (final port in device.ports) {
        if (port.kind != PortKind.busy && port.kind != PortKind.float) {
          continue;
        }
        final power = port.power;
        if (power == null) continue;
        items.add(
          _PowerItem(
            devAddress: device.devAddress,
            no: port.no,
            kind: port.kind,
            power: power,
          ),
        );
      }
    }
    return items;
  }

  List<_PowerItem> _pickPower(List<_PowerItem> items) {
    final soon = items
        .where((item) => item.kind == PortKind.float || item.power.w < 40)
        .take(3)
        .toList();
    final rest = items
        .where((item) => item.kind != PortKind.float && item.power.w >= 40)
        .toList();
    final byDevice = <String, List<_PowerItem>>{};
    for (final item in rest) {
      byDevice.putIfAbsent(item.devAddress, () => []).add(item);
    }
    final picked = [...soon];
    var index = 0;
    while (picked.length < 8) {
      var added = false;
      for (final list in byDevice.values) {
        if (index < list.length && picked.length < 8) {
          picked.add(list[index]);
          added = true;
        }
      }
      if (!added) break;
      index++;
    }
    return picked;
  }

  String _powerLabel(Station station, _PowerItem item) {
    final devicePrefix = station.devices.length > 1
        ? '${item.devAddress.substring(math.max(0, item.devAddress.length - 2))}·'
        : '';
    return '$devicePrefix${item.no}口';
  }
}

class _PowerItem {
  const _PowerItem({
    required this.devAddress,
    required this.no,
    required this.kind,
    required this.power,
  });

  final String devAddress;
  final int no;
  final PortKind kind;
  final PowerTelemetry power;
}

class _PowerChip extends StatelessWidget {
  const _PowerChip({
    required this.label,
    required this.power,
    required this.soon,
  });

  final String label;
  final PowerTelemetry power;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soon ? const Color(0x1A5C875C) : const Color(0x1ABC5A4C),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: soon ? const Color(0x4D5C875C) : const Color(0x40BC5A4C),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '${power.w.round()}W',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: soon ? AppColors.free : AppColors.busy,
              ),
            ),
            if (soon) const TextSpan(text: ' · 将满'),
          ],
        ),
      ),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0x1AA26B4A), Color(0x08A26B4A)],
          stops: [0, 0.7],
        ),
        border: Border.all(color: const Color(0x38A26B4A)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 4,
            child: Text(
              '北',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.sub,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(26, 26),
            painter: _NeedlePainter(bearing: bearing),
          ),
        ],
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({required this.bearing});

  final double bearing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(bearing * math.pi / 180);
    final path = Path()
      ..moveTo(0, -11)
      ..lineTo(7, 9)
      ..lineTo(0, 5)
      ..lineTo(-7, 9)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) {
    return oldDelegate.bearing != bearing;
  }
}
