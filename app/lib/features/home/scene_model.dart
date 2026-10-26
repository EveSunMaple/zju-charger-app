import 'dart:math' as math;

import '../../models/snapshot.dart';

class Offset3 {
  const Offset3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

class ScenePoint {
  const ScenePoint(this.p3, this.p2);

  final Offset3 p3;
  final Offset3 p2;
}

class SceneGroup {
  const SceneGroup({
    required this.points,
    required this.alpha,
    required this.delay,
    required this.fade2d,
    required this.size,
  });

  final List<ScenePoint> points;
  final double alpha;
  final double delay;
  final bool fade2d;
  final double size;
}

class ScenePort {
  const ScenePort({
    required this.index,
    required this.kind,
    required this.cx,
    required this.cy,
    required this.half,
    required this.z3,
    required this.pulse,
  });

  final int index;
  final PortKind kind;
  final double cx;
  final double cy;
  final double half;
  final double z3;
  final double pulse;
}

class SceneOfflineSlot {
  const SceneOfflineSlot({
    required this.cx,
    required this.cy,
    required this.half,
    required this.halfY,
  });

  final double cx;
  final double cy;
  final double half;
  final double halfY;
}

class SceneModel {
  const SceneModel({
    required this.groups,
    required this.ports,
    required this.offlineSlots,
    required this.width,
    required this.height,
    required this.depth,
    required this.modelWidth,
    required this.modelHeight,
    required this.liveDevices,
    required this.freePortNumbers,
  });

  final List<SceneGroup> groups;
  final List<ScenePort> ports;
  final List<SceneOfflineSlot> offlineSlots;
  final double width;
  final double height;
  final double depth;
  final double modelWidth;
  final double modelHeight;
  final int liveDevices;
  final List<int> freePortNumbers;
}

const _cols = 2;
const _cell = 13.0;
const _gap = 4.0;
const _devGap = 11.0;
const _pad = 12.0;
const _deviceRows = 6;
const _depth = 34.0;
const _roofH = 12.0;
const _roofGap = 10.0;
const _roofOver = 14.0;
const _roofDepth = 8.0;

SceneModel buildSceneModel(Station station) {
  final live = station.devices.where((device) => !device.offline).toList();
  const devW = _cols * _cell + (_cols - 1) * _gap;
  const devH = _deviceRows * _cell + (_deviceRows - 1) * _gap;
  final deviceCount = math.max(1, live.length);
  final width = deviceCount * devW + (deviceCount - 1) * _devGap;
  const height = devH;
  final groundY = height / 2 + _pad + 24;
  final halfW = width / 2 + _pad;
  final halfH = height / 2 + _pad;
  final groups = <SceneGroup>[];

  void addGroup(
    List<ScenePoint> points, {
    double alpha = 0.58,
    double delay = 0,
    bool fade2d = false,
    double size = 1.7,
  }) {
    groups.add(
      SceneGroup(
        points: points,
        alpha: alpha,
        delay: delay,
        fade2d: fade2d,
        size: size,
      ),
    );
  }

  List<Offset3> line(Offset3 a, Offset3 b, double step) {
    final length = math.sqrt(
      math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2) + math.pow(b.z - a.z, 2),
    );
    final count = math.max(2, (length / step).round());
    return List.generate(count + 1, (index) {
      final t = index / count;
      return Offset3(
        _lerp(a.x, b.x, t),
        _lerp(a.y, b.y, t),
        _lerp(a.z, b.z, t),
      );
    });
  }

  void pairLine(
    Offset3 a3,
    Offset3 b3,
    Offset3 a2,
    Offset3 b2,
    double step, {
    double alpha = 0.58,
    double delay = 0,
    bool fade2d = false,
    double size = 1.7,
  }) {
    final length = math.sqrt(
      math.pow(b3.x - a3.x, 2) +
          math.pow(b3.y - a3.y, 2) +
          math.pow(b3.z - a3.z, 2),
    );
    final count = math.max(2, (length / step).round());
    final points = List.generate(count + 1, (index) {
      final t = index / count;
      return ScenePoint(
        Offset3(
          _lerp(a3.x, b3.x, t),
          _lerp(a3.y, b3.y, t),
          _lerp(a3.z, b3.z, t),
        ),
        Offset3(_lerp(a2.x, b2.x, t), _lerp(a2.y, b2.y, t), 0),
      );
    });
    addGroup(points, alpha: alpha, delay: delay, fade2d: fade2d, size: size);
  }

  pairLine(
    Offset3(-halfW, -halfH, _depth / 2),
    Offset3(halfW, -halfH, _depth / 2),
    Offset3(-halfW, -halfH, 0),
    Offset3(halfW, -halfH, 0),
    8,
    delay: 0.04,
  );
  pairLine(
    Offset3(-halfW, halfH, _depth / 2),
    Offset3(halfW, halfH, _depth / 2),
    Offset3(-halfW, halfH, 0),
    Offset3(halfW, halfH, 0),
    8,
    delay: 0.06,
  );
  pairLine(
    Offset3(-halfW, -halfH, _depth / 2),
    Offset3(-halfW, halfH, _depth / 2),
    Offset3(-halfW, -halfH, 0),
    Offset3(-halfW, halfH, 0),
    8,
    delay: 0.05,
  );
  pairLine(
    Offset3(halfW, -halfH, _depth / 2),
    Offset3(halfW, halfH, _depth / 2),
    Offset3(halfW, -halfH, 0),
    Offset3(halfW, halfH, 0),
    8,
    delay: 0.05,
  );
  pairLine(
    Offset3(-halfW, -halfH, -_depth / 2),
    Offset3(-halfW, halfH, -_depth / 2),
    Offset3(-halfW, -halfH, 0),
    Offset3(-halfW, halfH, 0),
    8,
    delay: 0.05,
    alpha: 0.38,
  );
  pairLine(
    Offset3(halfW, -halfH, -_depth / 2),
    Offset3(halfW, halfH, -_depth / 2),
    Offset3(halfW, -halfH, 0),
    Offset3(halfW, halfH, 0),
    8,
    delay: 0.05,
    alpha: 0.38,
  );

  const inset = 5.0;
  pairLine(
    Offset3(-halfW, -halfH, -_depth / 2),
    Offset3(halfW, -halfH, -_depth / 2),
    Offset3(-halfW + inset, -halfH + inset, 0),
    Offset3(halfW - inset, -halfH + inset, 0),
    8,
    delay: 0.08,
    alpha: 0.4,
  );
  pairLine(
    Offset3(-halfW, -halfH, _depth / 2),
    Offset3(-halfW, -halfH, -_depth / 2),
    Offset3(-halfW + inset, -halfH + inset, 0),
    Offset3(-halfW + inset, -halfH + inset, 0),
    8,
    delay: 0.08,
    alpha: 0.4,
  );
  pairLine(
    Offset3(halfW, -halfH, _depth / 2),
    Offset3(halfW, -halfH, -_depth / 2),
    Offset3(halfW - inset, -halfH + inset, 0),
    Offset3(halfW - inset, -halfH + inset, 0),
    8,
    delay: 0.08,
    alpha: 0.4,
  );

  final random = _ModelRandom(station.name.hashCode);
  final dust = List.generate(90, (_) {
    final x = (random.next() * 2 - 1) * halfW;
    final y = (random.next() * 2 - 1) * halfH;
    return ScenePoint(Offset3(x, y, _depth / 2 + 0.5), Offset3(x, y, 0));
  });
  addGroup(dust, alpha: 0.22, delay: 0.12, fade2d: true, size: 1.3);

  final dividers = <ScenePoint>[];
  for (var i = 1; i < deviceCount; i++) {
    final x = -halfW + i * (devW + _devGap) - _devGap / 2;
    for (final point in line(
      Offset3(x, -halfH + 3, _depth / 2 + 0.5),
      Offset3(x, halfH - 3, _depth / 2 + 0.5),
      10,
    )) {
      dividers.add(ScenePoint(point, Offset3(point.x, point.y, 0)));
    }
  }
  addGroup(dividers, alpha: 0.16, delay: 0.10, fade2d: true, size: 1.2);

  final roofY1 = -halfH - _roofGap - _roofH;
  final roofY2 = -halfH - _roofGap;
  pairLine(
    Offset3(-(halfW + _roofOver), roofY1, -_roofDepth / 2),
    Offset3(halfW + _roofOver, roofY1, -_roofDepth / 2),
    Offset3(-(halfW + _roofOver), -_roofDepth / 2, 0),
    Offset3(halfW + _roofOver, -_roofDepth / 2, 0),
    9,
    alpha: 0.5,
  );
  pairLine(
    Offset3(-(halfW + _roofOver), roofY2, -_roofDepth / 2),
    Offset3(halfW + _roofOver, roofY2, -_roofDepth / 2),
    Offset3(-(halfW + _roofOver), _roofDepth / 2, 0),
    Offset3(halfW + _roofOver, _roofDepth / 2, 0),
    9,
    alpha: 0.5,
  );
  pairLine(
    Offset3(-(halfW + _roofOver), roofY1, -_roofDepth / 2),
    Offset3(-(halfW + _roofOver), roofY2, -_roofDepth / 2),
    Offset3(-(halfW + _roofOver), -_roofDepth / 2, 0),
    Offset3(-(halfW + _roofOver), _roofDepth / 2, 0),
    6,
    alpha: 0.5,
  );
  pairLine(
    Offset3(halfW + _roofOver, roofY1, -_roofDepth / 2),
    Offset3(halfW + _roofOver, roofY2, -_roofDepth / 2),
    Offset3(halfW + _roofOver, -_roofDepth / 2, 0),
    Offset3(halfW + _roofOver, _roofDepth / 2, 0),
    6,
    alpha: 0.5,
  );

  final pillars = <ScenePoint>[];
  for (final side in [-1, 1]) {
    final x = side * (halfW + _roofOver - 5);
    for (final point in line(
      Offset3(x, roofY2, 0),
      Offset3(x, groundY, 0),
      8,
    )) {
      pillars.add(ScenePoint(point, Offset3(x, 0, 0)));
    }
  }
  addGroup(pillars, alpha: 0.5, delay: 0.02, size: 1.9);

  final ground = <ScenePoint>[];
  for (var x = -halfW - 18; x <= halfW + 18; x += 9) {
    if ((x / 9).round() % 2 == 0) continue;
    ground.add(ScenePoint(Offset3(x, groundY, 0), Offset3(x, groundY, 0)));
  }
  addGroup(ground, alpha: 0.3, delay: 0.14, fade2d: true, size: 1.4);

  final ports = <ScenePort>[];
  final freePortNumbers = <int>[];
  var portIndex = 0;
  for (var deviceIndex = 0; deviceIndex < live.length; deviceIndex++) {
    final device = live[deviceIndex];
    final originX = -width / 2 + deviceIndex * (devW + _devGap);
    for (final port in device.ports) {
      final row = (port.no - 1) ~/ _cols;
      final col = (port.no - 1) % _cols;
      final px = originX + col * (_cell + _gap) + _cell / 2;
      final py = -height / 2 + row * (_cell + _gap) + _cell / 2;
      portIndex++;
      if (port.kind == PortKind.free) {
        freePortNumbers.add(portIndex);
      }
      ports.add(
        ScenePort(
          index: portIndex,
          kind: port.kind,
          cx: px,
          cy: py,
          half: _cell / 2 - 0.5,
          z3: _depth / 2 + 1,
          pulse: (portIndex * 2.39996) % (math.pi * 2),
        ),
      );
    }
  }

  final offlineSlots = <SceneOfflineSlot>[];
  for (
    var deviceIndex = 0;
    deviceIndex < station.devices.length;
    deviceIndex++
  ) {
    final device = station.devices[deviceIndex];
    if (!device.offline) continue;
    final originX = -width / 2 + deviceIndex * (devW + _devGap);
    offlineSlots.add(
      SceneOfflineSlot(
        cx: originX + devW / 2,
        cy: 0,
        half: devW / 2 - 0.5,
        halfY: devH / 2 - 0.5,
      ),
    );
  }

  return SceneModel(
    groups: groups,
    ports: ports,
    offlineSlots: offlineSlots,
    width: width,
    height: height,
    depth: _depth,
    modelWidth: width + 2 * (_pad + _roofOver) + 10,
    modelHeight:
        height +
        2 * _pad +
        _roofGap +
        _roofH +
        groundY -
        height / 2 -
        _pad +
        34,
    liveDevices: live.length,
    freePortNumbers: freePortNumbers,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _ModelRandom {
  _ModelRandom(int seed) : _seed = seed & 0x7fffffff;

  int _seed;

  double next() {
    _seed = (_seed * 1664525 + 1013904223) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
