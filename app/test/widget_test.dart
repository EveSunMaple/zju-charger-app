import 'package:flutter_test/flutter_test.dart';
import 'package:zju_charger/core/geo.dart';

void main() {
  test('destPoint produces the requested distance', () {
    const startLat = 30.30;
    const startLon = 120.09;
    final point = destPoint(startLat, startLon, 205, 200);
    final distance = haversine(startLat, startLon, point.lat, point.lon);
    expect(distance, closeTo(200, 0.5));
  });

  test('haversine is zero for the same point', () {
    expect(haversine(30.30, 120.09, 30.30, 120.09), 0);
  });
}
