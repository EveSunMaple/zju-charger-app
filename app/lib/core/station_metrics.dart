import '../models/snapshot.dart';

int soonPortCount(Station station) {
  var count = station.float;
  for (final device in station.devices) {
    if (device.offline) continue;
    for (final port in device.ports) {
      if (port.kind == PortKind.busy &&
          port.power != null &&
          port.power!.w < 40) {
        count++;
      }
    }
  }
  return count;
}

List<Port> visiblePorts(Station station, {int limit = 14}) {
  final ports = <Port>[];
  for (final device in station.devices) {
    if (device.offline) continue;
    for (final port in device.ports) {
      ports.add(port);
      if (ports.length >= limit) return ports;
    }
  }
  return ports;
}
