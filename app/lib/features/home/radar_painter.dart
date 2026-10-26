import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';

const radarSize = 212.0;
const _center = 106.0;
const _maxRadius = 100.0;

double radarMaxDistance(List<StationDistance> positions) {
  if (positions.isEmpty) return 1000;
  final maxD = math.min(3000.0, positions.last.distance);
  return math.max(maxD, 300);
}

double radarRadius(double distance, double maxDistance) {
  return _maxRadius *
      math.log(1 + distance / 40) /
      math.log(1 + maxDistance / 40);
}

class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.positions,
    required this.targetName,
  });

  final List<StationDistance> positions;
  final String targetName;

  @override
  void paint(Canvas canvas, Size size) {
    final maxD = radarMaxDistance(positions);
    final ringPaint = Paint()..style = PaintingStyle.stroke;
    for (final k in [0.33, 0.66, 1.0]) {
      ringPaint
        ..strokeWidth = 1
        ..color = Color.fromRGBO(96, 80, 60, 0.16 - k * 0.04);
      canvas.drawCircle(
        const Offset(_center, _center),
        _maxRadius * k,
        ringPaint,
      );
    }
    canvas.drawLine(
      const Offset(_center, _center - _maxRadius - 8),
      const Offset(_center, _center - _maxRadius + 2),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0x6660503C),
    );
    _drawText(
      canvas,
      '北',
      const Offset(_center, _center - _maxRadius - 6),
      9,
      AppColors.sub,
      fontWeight: FontWeight.w700,
    );

    final labeled = <String>{};
    for (final item in positions) {
      final station = item.station;
      final r = math.max(4.0, radarRadius(item.distance, maxD));
      final angle = rad(item.bearing);
      final x = _center + r * math.sin(angle);
      final y = _center - r * math.cos(angle);
      final color = station.free > 0 ? AppColors.free : AppColors.busy;
      final isTarget = station.name == targetName;
      if (isTarget) {
        canvas.drawCircle(
          Offset(x, y),
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = color.withValues(alpha: 0.9),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        isTarget ? 5 : 3.6,
        Paint()..color = color,
      );
      if (isTarget || (labeled.length < 3 && item.distance < maxD * 0.9)) {
        labeled.add(station.name);
        final label = station.name.length > 6
            ? station.name.substring(0, 6)
            : station.name;
        _drawText(
          canvas,
          label,
          Offset(x + 8, y),
          8.5,
          const Color(0xFF6E6252),
          alignLeft: true,
        );
      }
    }

    canvas.drawCircle(
      const Offset(_center, _center),
      12,
      Paint()..color = AppColors.accent.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      const Offset(_center, _center),
      4.5,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      const Offset(_center, _center),
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.card,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    FontWeight fontWeight = FontWeight.w700,
    bool alignLeft = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = alignLeft
        ? Offset(center.dx, center.dy - painter.height / 2)
        : center - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.targetName != targetName ||
        oldDelegate.positions.length != positions.length ||
        !_samePositions(oldDelegate.positions, positions);
  }

  bool _samePositions(
    List<StationDistance> a,
    List<StationDistance> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].station.name != b[i].station.name ||
          a[i].distance != b[i].distance ||
          a[i].bearing != b[i].bearing) {
        return false;
      }
    }
    return true;
  }
}

Station? radarHitTest(
  Offset position,
  List<StationDistance> positions,
) {
  final maxD = radarMaxDistance(positions);
  StationDistance? nearest;
  var nearestDistance = 14.0;
  for (final item in positions) {
    final r = math.max(4.0, radarRadius(item.distance, maxD));
    final angle = rad(item.bearing);
    final x = _center + r * math.sin(angle);
    final y = _center - r * math.cos(angle);
    final d = math.sqrt(
      math.pow(position.dx - x, 2) + math.pow(position.dy - y, 2),
    );
    if (d < nearestDistance) {
      nearestDistance = d.toDouble();
      nearest = item;
    }
  }
  return nearest?.station;
}
