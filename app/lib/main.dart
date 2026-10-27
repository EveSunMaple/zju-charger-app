import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/local_store.dart';
import 'core/push_service.dart';
import 'data/snapshot_repository.dart';
import 'state/demo_state.dart';
import 'state/preferences_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final repository = SnapshotRepository(apiBaseUrl: apiBaseUrl);
  final localStore = await LocalStore.load();
  final pushService = PushService();
  await pushService.init();
  final snapshot = await repository.load();
  runApp(
    ProviderScope(
      overrides: [
        snapshotProvider.overrideWithValue(snapshot),
        snapshotRepositoryProvider.overrideWithValue(repository),
        localStoreProvider.overrideWithValue(localStore),
        pushServiceProvider.overrideWithValue(pushService),
      ],
      child: const ZjuChargerApp(),
    ),
  );
}
