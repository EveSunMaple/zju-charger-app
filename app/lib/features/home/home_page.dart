import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'hero_card.dart';
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
                  _ScenePlaceholder(),
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

class _ScenePlaceholder extends StatelessWidget {
  const _ScenePlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '紫金港玉湖 · 紫金港校区',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle,
                ),
              ),
              Text('200 m', style: AppText.small),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: AppColors.card2,
              borderRadius: BorderRadius.circular(16),
              gradient: const RadialGradient(
                center: Alignment(0, 0.25),
                radius: 0.8,
                colors: [Color(0x0DA26B4A), AppColors.card2],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '3D 点云将在下一步接入',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
