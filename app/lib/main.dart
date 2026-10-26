import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/snapshot_repository.dart';
import 'state/demo_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final snapshot = await SnapshotRepository().load();
  runApp(
    ProviderScope(
      overrides: [snapshotProvider.overrideWithValue(snapshot)],
      child: const ZjuChargerApp(),
    ),
  );
}
