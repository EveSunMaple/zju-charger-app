import 'dart:math' as math;

const double earthRadius = 6371000;
const double simBearing = 205;

double rad(double degrees) => degrees * math.pi / 180;

double haversine(double lat1, double lon1, double lat2, double lon2) {
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double bearing(double lat1, double lon1, double lat2, double lon2) {
  final y = math.sin(rad(lon2 - lon1)) * math.cos(rad(lat2));
  final x =
      math.cos(rad(lat1)) * math.sin(rad(lat2)) -
      math.sin(rad(lat1)) * math.cos(rad(lat2)) * math.cos(rad(lon2 - lon1));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

GeoPoint destPoint(double lat, double lon, double bearingDeg, double distance) {
  final d = distance / earthRadius;
  final b = rad(bearingDeg);
  final la = rad(lat);
  final lo = rad(lon);
  final la2 = math.asin(
    math.sin(la) * math.cos(d) + math.cos(la) * math.sin(d) * math.cos(b),
  );
  final lo2 =
      lo +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(la),
        math.cos(d) - math.sin(la) * math.sin(la2),
      );
  return GeoPoint(la2 * 180 / math.pi, lo2 * 180 / math.pi);
}

class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;
}

double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double easeInOutCubic(double t) {
  if (t < 0.5) return 4 * t * t * t;
  return 1 - math.pow(-2 * t + 2, 3) / 2;
}

double easeOutCubic(double t) => (1 - math.pow(1 - t, 3)).toDouble();

int hashString(String value) {
  var hash = 0;
  for (var i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.codeUnitAt(i)) | 0;
  }
  return hash.abs();
}
