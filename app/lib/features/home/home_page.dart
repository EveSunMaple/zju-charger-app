import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'hero_card.dart';
import 'scene_card.dart';
import 'top_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 24 + bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  TopBar(),
                  HeroCard(),
                  SceneCard(),
                  _RadarPlaceholder(),
                  _NearbyPlaceholder(),
                  _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPlaceholder extends StatelessWidget {
  const _RadarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 160,
        child: Center(
          child: Text(
            '雷达与附近站点将在下一步接入',
            style: TextStyle(fontSize: 12, color: AppColors.sub),
          ),
        ),
      ),
    );
  }
}

class _NearbyPlaceholder extends StatelessWidget {
  const _NearbyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '附近列表将在下一步接入',
            style: TextStyle(fontSize: 12, color: AppColors.sub),
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
        style: TextStyle(
          fontSize: 10,
          height: 1.7,
          color: AppColors.sub,
        ),
      ),
    );
  }
}
