import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/station_metrics.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';

class NearbyList extends StatelessWidget {
  const NearbyList({
    super.key,
    required this.positions,
    required this.targetName,
    required this.onSelect,
  });

  final List<StationDistance> positions;
  final String targetName;
  final ValueChanged<Station> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = positions.take(12).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _NearbyRow(
            item: items[i],
            active: items[i].station.name == targetName,
            onTap: () => onSelect(items[i].station),
          ),
        ],
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final StationDistance item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final station = item.station;
    final soon = soonPortCount(station);
    final ports = visiblePorts(station);
    return Material(
      color: active ? const Color(0x0FA26B4A) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0x33A26B4A) : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDistance(item.distance),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  _Chip(
                    label: '空闲 ${station.free}/${station.total}',
                    color: station.free > 0 ? AppColors.free : AppColors.busy,
                  ),
                  if (station.fault > 0)
                    _Chip(label: '故障 ${station.fault}', color: AppColors.fault),
                  if (station.offline > 0)
                    _Chip(
                      label: '离线 ${station.offline}',
                      color: AppColors.fault,
                    ),
                  if (soon > 0) _Chip(label: '将满 $soon', color: AppColors.free),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  for (final port in ports)
                    Padding(
                      padding: const EdgeInsets.only(right: 2.5),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _portColor(port.kind),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _portColor(PortKind kind) {
    switch (kind) {
      case PortKind.free:
        return AppColors.free;
      case PortKind.busy:
        return AppColors.busy;
      case PortKind.float:
        return AppColors.warn;
      case PortKind.storage:
        return AppColors.storage;
      case PortKind.fault:
        return AppColors.fault;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
