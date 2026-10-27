import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../data/snapshot_repository.dart';
import '../models/snapshot.dart';

enum SceneMode { threeD, topDown }

final snapshotProvider = Provider<ChargerSnapshot>((ref) {
  throw UnimplementedError('snapshotProvider must be overridden');
});

final snapshotRepositoryProvider = Provider<SnapshotRepository>(
  (ref) => const SnapshotRepository(),
);

final demoStateProvider = NotifierProvider<DemoStateNotifier, DemoState>(
  DemoStateNotifier.new,
);

class StationDistance {
  const StationDistance({
    required this.station,
    required this.distance,
    required this.bearing,
  });

  final Station station;
  final double distance;
  final double bearing;
}

class DemoState {
  const DemoState({
    required this.snapshot,
    required this.target,
    required this.simEnabled,
    required this.simDistance,
    required this.mode,
    required this.refreshing,
  });

  final ChargerSnapshot snapshot;
  final Station target;
  final bool simEnabled;
  final double simDistance;
  final SceneMode mode;
  final bool refreshing;

  GeoPoint get myPosition =>
      destPoint(target.lat, target.lon, simBearing, simDistance);

  double get distanceToTarget =>
      haversine(myPosition.lat, myPosition.lon, target.lat, target.lon);

  double get bearingToTarget =>
      bearing(myPosition.lat, myPosition.lon, target.lat, target.lon);

  List<StationDistance> get positions {
    final me = myPosition;
    final items = snapshot.stations.map((station) {
      return StationDistance(
        station: station,
        distance: haversine(me.lat, me.lon, station.lat, station.lon),
        bearing: bearing(me.lat, me.lon, station.lat, station.lon),
      );
    }).toList();
    items.sort((a, b) => a.distance.compareTo(b.distance));
    return items;
  }

  DemoState copyWith({
    ChargerSnapshot? snapshot,
    Station? target,
    bool? simEnabled,
    double? simDistance,
    SceneMode? mode,
    bool? refreshing,
  }) {
    return DemoState(
      snapshot: snapshot ?? this.snapshot,
      target: target ?? this.target,
      simEnabled: simEnabled ?? this.simEnabled,
      simDistance: simDistance ?? this.simDistance,
      mode: mode ?? this.mode,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

class DemoStateNotifier extends Notifier<DemoState> {
  bool _fetching = false;

  @override
  DemoState build() {
    final snapshot = ref.watch(snapshotProvider);
    final target = _defaultTarget(snapshot);
    return DemoState(
      snapshot: snapshot,
      target: target,
      simEnabled: true,
      simDistance: 200,
      mode: SceneMode.threeD,
      refreshing: false,
    );
  }

  void selectStation(String name) {
    Station? next;
    for (final station in state.snapshot.stations) {
      if (station.name == name) {
        next = station;
        break;
      }
    }
    if (next == null || next.name == state.target.name) return;
    state = state.copyWith(
      target: next,
      mode: state.simDistance < 25 ? SceneMode.topDown : SceneMode.threeD,
    );
  }

  void setSimDistance(double distance) {
    final next = clampDouble(distance, 5, 3000);
    var mode = state.mode;
    if (mode == SceneMode.threeD && next < 25) {
      mode = SceneMode.topDown;
    } else if (mode == SceneMode.topDown && next > 40) {
      mode = SceneMode.threeD;
    }
    state = state.copyWith(simDistance: next, mode: mode);
  }

  void setSimEnabled(bool enabled) {
    state = state.copyWith(simEnabled: enabled);
  }

  Future<bool> refresh({bool silent = false}) async {
    if (_fetching) return false;
    final repository = ref.read(snapshotRepositoryProvider);
    if (repository.apiBaseUrl.trim().isEmpty) return false;
    _fetching = true;
    if (!silent) state = state.copyWith(refreshing: true);
    try {
      final next = await repository.fetchApi();
      if (next == null) return false;
      final target =
          _stationByName(next, state.target.name) ?? _defaultTarget(next);
      state = state.copyWith(snapshot: next, target: target);
      return true;
    } finally {
      _fetching = false;
      if (!silent) state = state.copyWith(refreshing: false);
    }
  }
}

Station? _stationByName(ChargerSnapshot snapshot, String name) {
  for (final station in snapshot.stations) {
    if (station.name == name) return station;
  }
  return null;
}

Station _defaultTarget(ChargerSnapshot snapshot) {
  if (snapshot.stations.isEmpty) {
    throw StateError('snapshot has no stations');
  }
  for (final station in snapshot.stations) {
    if (station.name == '紫金港玉湖') return station;
  }
  final available = snapshot.stations.where((station) => station.free > 0);
  return available.isNotEmpty ? available.first : snapshot.stations.first;
}
