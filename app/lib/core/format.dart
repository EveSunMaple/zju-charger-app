String formatDistance(double? meters) {
  if (meters == null) return '--';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String formatDistanceValue(double? meters) {
  if (meters == null) return '--';
  if (meters < 1000) return '${meters.round()}';
  return (meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0);
}

String formatDistanceUnit(double? meters) {
  if (meters == null || meters < 1000) return 'm';
  return 'km';
}

String formatEta(double meters) {
  final seconds = meters / 4.0;
  if (seconds < 60) return '骑行 1 分钟内';
  final minutes = (seconds / 60).ceil();
  return '骑行 $minutes 分钟';
}

String formatAge(DateTime fetchedAt, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).difference(fetchedAt);
  final seconds = delta.inSeconds;
  if (seconds < 60) return '刚刚';
  if (seconds < 3600) return '${(seconds / 60).round()} 分钟前';
  if (seconds < 86400) return '${(seconds / 3600).round()} 小时前';
  return '${(seconds / 86400).round()} 天前';
}

String formatSnapshotTime(DateTime fetchedAt) {
  final hh = fetchedAt.hour.toString().padLeft(2, '0');
  final mm = fetchedAt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

bool isSnapshotStale(DateTime fetchedAt, {DateTime? now}) {
  return (now ?? DateTime.now()).difference(fetchedAt).inMinutes > 5;
}
