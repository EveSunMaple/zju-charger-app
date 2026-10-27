import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push_service.dart';
import '../data/snapshot_repository.dart';
import 'demo_state.dart';
import 'preferences_state.dart';

class ReminderService {
  ReminderService({
    required this.repository,
    required this.pushService,
    required this.deviceId,
  });

  final SnapshotRepository repository;
  final PushService pushService;
  final String deviceId;

  bool get available =>
      repository.apiBaseUrl.trim().isNotEmpty && pushService.available;

  String get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<bool> sync(Set<String> stationNames) async {
    final token = pushService.token;
    if (!available || token == null) return false;
    return repository.registerDevice(
      deviceId: deviceId,
      platform: platform,
      pushToken: token,
      stationNames: stationNames,
    );
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    repository: ref.watch(snapshotRepositoryProvider),
    pushService: ref.watch(pushServiceProvider),
    deviceId: ref.watch(localStoreProvider).deviceId,
  );
});
