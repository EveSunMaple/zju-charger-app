import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zju_charger/core/geo.dart';
import 'package:zju_charger/core/local_store.dart';
import 'package:zju_charger/core/push_service.dart';
import 'package:zju_charger/core/theme.dart';
import 'package:zju_charger/features/home/home_page.dart';
import 'package:zju_charger/features/home/scene_model.dart';
import 'package:zju_charger/models/snapshot.dart';
import 'package:zju_charger/state/demo_state.dart';
import 'package:zju_charger/state/preferences_state.dart';

ChargerSnapshot _loadSnapshot() {
  final raw = File('assets/data/snapshot.json').readAsStringSync();
  return ChargerSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  test('destPoint produces the requested distance', () {
    const startLat = 30.30;
    const startLon = 120.09;
    final point = destPoint(startLat, startLon, 205, 200);
    final distance = haversine(startLat, startLon, point.lat, point.lon);
    expect(distance, closeTo(200, 0.5));
  });

  test('snapshot parses the expected station and port counts', () {
    final snapshot = _loadSnapshot();
    expect(snapshot.stations.length, 35);
    expect(snapshot.portTotal, 1644);
    final station = snapshot.stations.firstWhere(
      (item) => item.name == '紫金港玉湖',
    );
    expect(station.ports.length, 96);
    expect(station.free, 4);
    expect(station.float, 5);
  });

  test('scene model mirrors the station port layout', () {
    final snapshot = _loadSnapshot();
    final station = snapshot.stations.firstWhere(
      (item) => item.name == '紫金港玉湖',
    );
    final model = buildSceneModel(station);
    expect(model.liveDevices, 8);
    expect(model.ports.length, 96);
    expect(model.freePortNumbers.length, 4);
    expect(model.modelWidth, greaterThan(0));
    expect(model.modelHeight, greaterThan(0));
  });

  test('distance changes respect the 25m/40m hysteresis', () {
    final snapshot = _loadSnapshot();
    final container = ProviderContainer(
      overrides: [snapshotProvider.overrideWithValue(snapshot)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(demoStateProvider.notifier);
    expect(container.read(demoStateProvider).mode, SceneMode.threeD);

    notifier.setSimDistance(10);
    expect(container.read(demoStateProvider).mode, SceneMode.topDown);

    notifier.setSimDistance(30);
    expect(container.read(demoStateProvider).mode, SceneMode.topDown);

    notifier.setSimDistance(41);
    expect(container.read(demoStateProvider).mode, SceneMode.threeD);

    notifier.selectStation('紫金港医学院南侧');
    expect(container.read(demoStateProvider).target.name, '紫金港医学院南侧');
  });

  test('local store persists favorites and reminders in memory', () async {
    final store = LocalStore.memory();
    expect(await store.toggleFavorite('A'), isTrue);
    expect(await store.toggleReminder('A'), isTrue);
    expect(store.favorites, contains('A'));
    expect(store.reminders, contains('A'));
    expect(await store.toggleFavorite('A'), isFalse);
    expect(store.favorites, isNot(contains('A')));
  });

  testWidgets('notification tap selects the station', (tester) async {
    final snapshot = _loadSnapshot();
    final pushService = PushService();
    final container = ProviderContainer(
      overrides: [
        snapshotProvider.overrideWithValue(snapshot),
        pushServiceProvider.overrideWithValue(pushService),
        localStoreProvider.overrideWithValue(LocalStore.memory()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(pushService.dispose);
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    pushService.openedStation.value = '紫金港医学院南侧';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(demoStateProvider).target.name, '紫金港医学院南侧');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home fits a 375px wide screen without overflow', (tester) async {
    final snapshot = _loadSnapshot();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [snapshotProvider.overrideWithValue(snapshot)],
        child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home renders and the debug sheet switches to 2D', (
    tester,
  ) async {
    final snapshot = _loadSnapshot();
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [snapshotProvider.overrideWithValue(snapshot)],
        child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('紫金港玉湖'), findsWidgets);
    expect(find.text('3D 点云'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('演示控制'), findsOneWidget);

    await tester.tap(find.text('10 m'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('当前：2D 俯视 · 精密导航'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('2D 俯视 · 精密导航'), findsWidgets);
    expect(find.textContaining('个插口空闲', findRichText: true), findsOneWidget);
    expect(find.textContaining('实时功率'), findsOneWidget);
    expect(find.text('打开地图精确导航'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
