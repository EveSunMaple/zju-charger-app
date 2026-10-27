import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/snapshot_repository.dart';
import 'state/demo_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final repository = SnapshotRepository(apiBaseUrl: apiBaseUrl);
  final snapshot = await repository.load();
  runApp(
    ProviderScope(
      overrides: [
        snapshotProvider.overrideWithValue(snapshot),
        snapshotRepositoryProvider.overrideWithValue(repository),
      ],
      child: const ZjuChargerApp(),
    ),
  );
}
