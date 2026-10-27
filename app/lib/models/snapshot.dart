enum PortKind { free, busy, float, storage, fault }

PortKind _kindFromString(String value, String code) {
  switch (value) {
    case 'free':
      return PortKind.free;
    case 'busy':
      return PortKind.busy;
    case 'float':
      return PortKind.float;
    case 'storage':
      return PortKind.storage;
    case 'fault':
      return PortKind.fault;
  }
  if (code == '0' || code == '6') return PortKind.free;
  if (code == '1') return PortKind.busy;
  if (code == '3') return PortKind.float;
  if (code == '4') return PortKind.storage;
  return PortKind.fault;
}

class PowerTelemetry {
  const PowerTelemetry({
    required this.w,
    required this.wMax,
    required this.a,
    required this.v,
    required this.wh,
    required this.mins,
    required this.at,
    required this.curve,
  });

  final double w;
  final double wMax;
  final double? a;
  final double? v;
  final double wh;
  final int mins;
  final String at;
  final List<double> curve;

  bool get soon => w < 40;

  factory PowerTelemetry.fromJson(Map<String, dynamic> json) {
    return PowerTelemetry(
      w: _asDouble(json['w']),
      wMax: _asDouble(json['wmax']),
      a: _asNullableDouble(json['a']),
      v: _asNullableDouble(json['v']),
      wh: _asDouble(json['wh']),
      mins: _asInt(json['mins']),
      at: json['at'] as String? ?? '',
      curve: (json['curve'] as List<dynamic>? ?? [])
          .map(_asDouble)
          .toList(growable: false),
    );
  }
}

class Port {
  const Port({
    required this.no,
    required this.code,
    required this.kind,
    required this.status,
    required this.free,
    this.power,
  });

  final int no;
  final String code;
  final PortKind kind;
  final String status;
  final bool free;
  final PowerTelemetry? power;

  factory Port.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final powerJson = json['power'];
    return Port(
      no: _asInt(json['no']),
      code: code,
      kind: _kindFromString(json['kind'] as String? ?? '', code),
      status: json['status'] as String? ?? '未知',
      free: json['free'] as bool? ?? false,
      power: powerJson is Map<String, dynamic>
          ? PowerTelemetry.fromJson(powerJson)
          : null,
    );
  }
}

class Device {
  const Device({
    required this.devAddress,
    required this.devTypeId,
    required this.description,
    required this.areaName,
    required this.workTime,
    required this.portSize,
    required this.raw,
    required this.ports,
    required this.free,
    required this.busy,
    required this.float,
    required this.storage,
    required this.fault,
    required this.offline,
    required this.offlineMessage,
  });

  final String devAddress;
  final int? devTypeId;
  final String? description;
  final String? areaName;
  final String? workTime;
  final int portSize;
  final String raw;
  final List<Port> ports;
  final int free;
  final int busy;
  final int float;
  final int storage;
  final int fault;
  final bool offline;
  final String? offlineMessage;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      devAddress: json['devaddress']?.toString() ?? '',
      devTypeId: json['devtypeid'] == null ? null : _asInt(json['devtypeid']),
      description: json['devdescript'] as String?,
      areaName: json['area_name'] as String?,
      workTime: json['work_time'] as String?,
      portSize: _asInt(json['port_size']),
      raw: json['raw'] as String? ?? '',
      ports: (json['ports'] as List<dynamic>? ?? [])
          .map((item) => Port.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      free: _asInt(json['free']),
      busy: _asInt(json['busy']),
      float: _asInt(json['float']),
      storage: _asInt(json['storage']),
      fault: _asInt(json['fault']),
      offline: json['offline'] as bool? ?? false,
      offlineMessage: json['offline_msg'] as String?,
    );
  }
}

class Station {
  const Station({
    required this.name,
    required this.provider,
    required this.campusId,
    required this.campusName,
    required this.lat,
    required this.lon,
    required this.free,
    required this.busy,
    required this.float,
    required this.storage,
    required this.fault,
    required this.total,
    required this.offline,
    required this.devices,
    this.observedAt,
  });

  final String name;
  final String provider;
  final int campusId;
  final String campusName;
  final double lat;
  final double lon;
  final int free;
  final int busy;
  final int float;
  final int storage;
  final int fault;
  final int total;
  final int offline;
  final List<Device> devices;
  final DateTime? observedAt;

  List<Port> get ports => devices
      .where((device) => !device.offline)
      .expand((device) => device.ports)
      .toList(growable: false);

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      name: json['name'] as String? ?? '未知站点',
      provider: json['provider'] as String? ?? '',
      campusId: _asInt(json['campus_id']),
      campusName: json['campus_name'] as String? ?? '',
      lat: _asDouble(json['lat']),
      lon: _asDouble(json['lon']),
      free: _asInt(json['free']),
      busy: _asInt(json['busy']),
      float: _asInt(json['float']),
      storage: _asInt(json['storage']),
      fault: _asInt(json['fault']),
      total: _asInt(json['total']),
      offline: _asInt(json['offline']),
      devices: (json['devices'] as List<dynamic>? ?? [])
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      observedAt: _parseDateTime(json['observed_at'] as String?),
    );
  }
}

class ChargerSnapshot {
  const ChargerSnapshot({
    required this.scope,
    required this.campuses,
    required this.fetchedAt,
    required this.stationCount,
    required this.deviceCount,
    required this.portTotal,
    required this.portFree,
    required this.portBusy,
    required this.portFloat,
    required this.portStorage,
    required this.portFault,
    required this.portOffline,
    required this.powerPorts,
    required this.stations,
    this.source = 'asset',
  });

  final String scope;
  final List<String> campuses;
  final DateTime fetchedAt;
  final int stationCount;
  final int deviceCount;
  final int portTotal;
  final int portFree;
  final int portBusy;
  final int portFloat;
  final int portStorage;
  final int portFault;
  final int portOffline;
  final int powerPorts;
  final List<Station> stations;
  final String source;

  factory ChargerSnapshot.fromJson(
    Map<String, dynamic> json, {
    String source = 'asset',
  }) {
    final fetchedAtText = json['fetched_at'] as String? ?? '';
    final parsedFetchedAt = DateTime.tryParse(
      fetchedAtText.replaceFirst(' ', 'T'),
    );
    return ChargerSnapshot(
      scope: json['scope'] as String? ?? '',
      campuses: (json['campuses'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(growable: false),
      fetchedAt: parsedFetchedAt ?? DateTime.now(),
      stationCount: _asInt(json['station_count']),
      deviceCount: _asInt(json['device_count']),
      portTotal: _asInt(json['port_total']),
      portFree: _asInt(json['port_free']),
      portBusy: _asInt(json['port_busy']),
      portFloat: _asInt(json['port_float']),
      portStorage: _asInt(json['port_storage']),
      portFault: _asInt(json['port_fault']),
      portOffline: _asInt(json['port_offline']),
      powerPorts: _asInt(json['power_ports']),
      stations: (json['stations'] as List<dynamic>? ?? [])
          .map((item) => Station.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      source: source,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  return _asDouble(value);
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}
