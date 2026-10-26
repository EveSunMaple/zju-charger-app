import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import 'scene_model.dart';

const _fov = 950.0;

class ProjectedPoint {
  const ProjectedPoint(this.x, this.y, this.scale);

  final double x;
  final double y;
  final double scale;
}

ProjectedPoint projectPoint(
  double x,
  double y,
  double z,
  double rotX,
  double rotY,
  double scale,
  double cx,
  double cy,
) {
  final cosY = math.cos(rotY);
  final sinY = math.sin(rotY);
  final x1 = x * cosY + z * sinY;
  final z1 = -x * sinY + z * cosY;
  final cosX = math.cos(rotX);
  final sinX = math.sin(rotX);
  final y1 = y * cosX - z1 * sinX;
  final z2 = y * sinX + z1 * cosX;
  final s = _fov / (_fov + z2);
  return ProjectedPoint(cx + x1 * scale * s, cy + y1 * scale * s, s);
}

class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.model,
    required this.modeT,
    required this.clock,
    required this.bearingToTarget,
    required this.stationName,
  }) : super(repaint: Listenable.merge([modeT, clock]));

  final SceneModel model;
  final Animation<double> modeT;
  final ValueNotifier<double> clock;
  final double bearingToTarget;
  final String stationName;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    if (size.width <= 0 || size.height <= 0) return;

    final t = modeT.value;
    final te = easeInOutCubic(t);
    final osc = 1 - te;
    final seconds = clock.value;
    final rotX = (-50 * (1 - te) + math.sin(seconds * 0.85) * 3.5 * osc) *
        math.pi /
        180;
    final rotY = (-15 * (1 - te) + math.sin(seconds * 0.6 + 1.3) * 7 * osc) *
        math.pi /
        180;
    final fit = math.min(
      1.0,
      math.min(
        (size.width - 26) / model.modelWidth,
        (size.height - 54) / model.modelHeight,
      ),
    );
    final scale = fit * _lerp(1, 0.88, te);
    final cx = size.width / 2;
    final cy = size.height * _lerp(0.47, 0.45, te);
    const span = 0.30;

    final paint = Paint()..style = PaintingStyle.fill;
    for (final group in model.groups) {
      final alpha = group.alpha * (group.fade2d ? (1 - te) : 1);
      if (alpha <= 0.01) continue;
      for (var index = 0; index < group.points.length; index++) {
        final point = group.points[index];
        final delay = group.delay + (index % 48) / 48 * 0.12;
        final progress = clampDouble(t * (1 + span) - delay, 0, 1);
        final eased = easeInOutCubic(progress);
        final x = _lerp(point.p3.x, point.p2.x, eased);
        final y = _lerp(point.p3.y, point.p2.y, eased);
        final z = _lerp(point.p3.z, point.p2.z, eased);
        final projected =
            projectPoint(x, y, z, rotX, rotY, scale, cx, cy);
        final radius =
            group.size * projected.scale * (0.85 + ((index * 37) % 10) / 40);
        final pointAlpha = alpha * (0.35 + 0.65 * projected.scale);
        paint.color = Color.fromRGBO(141, 127, 108, pointAlpha);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(projected.x, projected.y),
            width: radius,
            height: radius,
          ),
          paint,
        );
      }
    }

    for (final slot in model.offlineSlots) {
      final progress = easeInOutCubic(
        clampDouble(t * (1 + span) - 0.18, 0, 1),
      );
      final z = _lerp(model.depth / 2 + 1, 0, progress);
      final c1 = projectPoint(
        slot.cx - slot.half,
        -slot.halfY,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c2 = projectPoint(
        slot.cx + slot.half,
        -slot.halfY,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c3 = projectPoint(
        slot.cx + slot.half,
        slot.halfY,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c4 = projectPoint(
        slot.cx - slot.half,
        slot.halfY,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final path = Path()
        ..moveTo(c1.x, c1.y)
        ..lineTo(c2.x, c2.y)
        ..lineTo(c3.x, c3.y)
        ..lineTo(c4.x, c4.y)
        ..close();
      paint.color = Color.fromRGBO(214, 203, 184, 0.82 * progress + 0.1);
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x668D7F6C),
      );
      final mid = projectPoint(
        slot.cx,
        0,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      if (mid.scale > 0.8) {
        _drawText(
          canvas,
          '离线',
          Offset(mid.x, mid.y),
          9,
          const Color(0xE68D7F6C),
        );
      }
    }

    for (final port in model.ports) {
      final delay = 0.20 + (port.index % 24) / 24 * 0.10;
      final progress = clampDouble(t * (1 + span) - delay, 0, 1);
      final eased = easeInOutCubic(progress);
      final z = _lerp(port.z3, 0, eased);
      final half = port.half;
      final c1 = projectPoint(
        port.cx - half,
        port.cy - half,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c2 = projectPoint(
        port.cx + half,
        port.cy - half,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c3 = projectPoint(
        port.cx + half,
        port.cy + half,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final c4 = projectPoint(
        port.cx - half,
        port.cy + half,
        z,
        rotX,
        rotY,
        scale,
        cx,
        cy,
      );
      final avgScale = (c1.scale + c2.scale + c3.scale + c4.scale) / 4;
      if (avgScale < 0.12) continue;

      final color = _portColor(port.kind);
      var alpha = 0.92;
      if (port.kind == PortKind.free) {
        alpha = (t > 0.02 && t < 0.98)
            ? 0.9
            : 0.86 + 0.07 * math.sin(seconds * 0.9 + port.pulse);
      }
      final path = Path()
        ..moveTo(c1.x, c1.y)
        ..lineTo(c2.x, c2.y)
        ..lineTo(c3.x, c3.y)
        ..lineTo(c4.x, c4.y)
        ..close();
      paint.color = color.withValues(alpha: alpha);
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x2E3B342A),
      );

      if (port.kind == PortKind.float) {
        final cellPx = (c2.x - c1.x).abs() + (c3.y - c1.y).abs();
        if (cellPx > 15) {
          _drawText(
            canvas,
            '满',
            Offset((c1.x + c3.x) / 2, (c1.y + c3.y) / 2),
            math.max(6.5 * avgScale + 0.5, 6),
            AppColors.card,
          );
        }
      }
    }

    _paintNavigation(
      canvas,
      size,
      te: te,
      fit: fit,
      cx: cx,
      cy: cy,
      seconds: seconds,
    );
  }


  void _paintNavigation(
    Canvas canvas,
    Size size, {
    required double te,
    required double fit,
    required double cx,
    required double cy,
    required double seconds,
  }) {
    if (te <= 0.001) return;
    final routeAlpha = clampDouble((te - 0.04) / 0.22, 0, 1);
    final dotAlpha = clampDouble((te - 0.10) / 0.20, 0, 1);
    if (routeAlpha <= 0) return;

    final direction = (bearingToTarget + 180) % 360;
    final dirX = math.sin(direction * math.pi / 180);
    final dirY = -math.cos(direction * math.pi / 180);
    final radius = _orbitRadius(
      size,
      fit,
      dirX,
      dirY,
      te,
      30,
    );
    final x = size.width / 2 + dirX * radius;
    final y = size.height * _lerp(0.47, 0.45, te) + dirY * radius;

    final length = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
    if (length > 6) {
      final dx = (x - cx) / length;
      final dy = (y - cy) / length;
      final endRadius = _orbitRadius(size, fit, dx, dy, te, 9);
      final tx = cx + dx * endRadius;
      final ty = cy + dy * endRadius;
      final hash = hashString(stationName);
      final side = hash.isEven ? 1.0 : -1.0;
      final bow = math.min(26, math.max(0, length - endRadius) * 0.55) * side;
      final mx = (x + tx) / 2 - dy * bow;
      final my = (y + ty) / 2 + dx * bow;
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(mx, my, tx, ty);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 10
          ..color = AppColors.accent.withValues(alpha: 0.18 * routeAlpha),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3
          ..color = AppColors.accent.withValues(alpha: 0.55 * routeAlpha),
      );
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3.5
          ..color = AppColors.accent.withValues(alpha: routeAlpha),
        dash: 3.5,
        gap: 12.5,
        offset: -(seconds * 46) % 16,
      );
      canvas.drawCircle(
        Offset(tx, ty),
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: 0.85 * routeAlpha),
      );
      canvas.drawCircle(
        Offset(tx, ty),
        2,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.95 * routeAlpha),
      );
    }

    if (dotAlpha <= 0) return;
    canvas.drawCircle(
      Offset(x, y),
      8.75,
      Paint()..color = AppColors.card.withValues(alpha: dotAlpha),
    );
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()..color = AppColors.accent.withValues(alpha: dotAlpha),
    );

    canvas.save();
    canvas.translate(x, y - 14);
    canvas.rotate(bearingToTarget * math.pi / 180);
    final arrow = Path()
      ..moveTo(0, -12)
      ..lineTo(7, 6)
      ..lineTo(0, 1)
      ..lineTo(-7, 6)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()..color = AppColors.accent.withValues(alpha: dotAlpha),
    );
    canvas.restore();

    _drawText(
      canvas,
      '你',
      Offset(x, y + 16),
      9.5,
      AppColors.accent.withValues(alpha: dotAlpha),
    );
  }

  double _orbitRadius(
    Size size,
    double fit,
    double dx,
    double dy,
    double te,
    double pad,
  ) {
    final stageHalfW = size.width / 2 - 12;
    final stageHalfH = size.height / 2 - 26;
    final tSx = dx.abs() > 1e-4 ? stageHalfW / dx.abs() : 1e9;
    final tSy = dy.abs() > 1e-4 ? stageHalfH / dy.abs() : 1e9;
    final scale2d = fit * 0.88;
    final halfW = model.modelWidth / 2 * scale2d;
    final halfH = model.modelHeight / 2 * scale2d;
    final tEx = dx.abs() > 1e-4 ? halfW / dx.abs() : 1e9;
    final tEy = dy.abs() > 1e-4 ? halfH / dy.abs() : 1e9;
    final r1 = math.min(math.min(tEx, tEy) + pad, math.min(tSx, tSy));
    final r0 = clampDouble(math.min(size.width, size.height) * 0.46, 84, 240);
    return _lerp(r0, r1, te);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
    required double offset,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = offset % (dash + gap);
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        if (end > distance) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance += dash + gap;
      }
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.24),
          radius: 0.8,
          colors: [Color(0x0DA26B4A), Color(0x00F6F1E7)],
        ).createShader(rect),
    );
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var y = 0.0; y < size.height; y += 17) {
      final mask = ((y / size.height) - 0.34) / 0.48;
      final alpha = clampDouble(mask, 0, 1) * 0.13;
      if (alpha <= 0.002) continue;
      dotPaint.color = Color.fromRGBO(96, 80, 60, alpha);
      for (var x = 8.0; x < size.width; x += 17) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }
  }

  Color _portColor(PortKind kind) {
    switch (kind) {
      case PortKind.free:
        return AppColors.free;
      case PortKind.busy:
      case PortKind.float:
        return AppColors.busy;
      case PortKind.storage:
        return AppColors.storage;
      case PortKind.fault:
        return AppColors.fault;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.model != model;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
