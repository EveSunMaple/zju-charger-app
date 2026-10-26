import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/home/home_page.dart';

class ZjuChargerApp extends StatelessWidget {
  const ZjuChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '浙大充电桩',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
