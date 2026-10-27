import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push_service.dart';
import '../../core/theme.dart';
import '../../models/snapshot.dart';
import '../../state/demo_state.dart';
import '../../state/preferences_state.dart';
import '../../state/reminder_service.dart';
import '../debug/debug_sheet.dart';
import 'hero_card.dart';
import 'radar_card.dart';
import 'scene_card.dart';
import 'top_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _sceneKey = GlobalKey();
  late final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  late final PushService _pushService;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(demoStateProvider.notifier).refresh(silent: true);
    });
    _pushService = ref.read(pushServiceProvider);
    _pushService.openedStation.addListener(_onOpenedStation);
    if (_pushService.openedStation.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onOpenedStation());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reminderService = ref.read(reminderServiceProvider);
      final reminders = ref.read(stationPrefsProvider).reminders;
      if (reminderService.available && reminders.isNotEmpty) {
        reminderService.sync(reminders);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushService.openedStation.removeListener(_onOpenedStation);
    _scrollController.dispose();
    super.dispose();
  }

  void _onOpenedStation() {
    final name = _pushService.openedStation.value;
    if (name == null || name.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(demoStateProvider.notifier).selectStation(name);
      final context = _sceneKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
    });
  }

  void _scrollToScene(Station _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sceneKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'debug',
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.accent,
        elevation: 4,
        onPressed: () => showDebugSheet(context),
        child: const Icon(Icons.tune, size: 19),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(14, 10, 14, 24 + bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  const TopBar(),
                  const HeroCard(),
                  KeyedSubtree(key: _sceneKey, child: const SceneCard()),
                  RadarCard(onSelect: _scrollToScene),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '数据来源：量子新能 · 离线演示快照\n状态仅供参考，请以现场指示灯为准',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, height: 1.7, color: AppColors.sub),
      ),
    );
  }
}
