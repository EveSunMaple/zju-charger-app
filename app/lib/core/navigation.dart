import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/snapshot.dart';
import 'geo.dart';

Future<void> openAmapNavigation({
  required BuildContext context,
  required Station station,
  required GeoPoint from,
}) async {
  final uri = Uri.https('uri.amap.com', '/navigation', {
    'from': '${from.lon.toStringAsFixed(6)},'
        '${from.lat.toStringAsFixed(6)},我的位置',
    'to': '${station.lon.toStringAsFixed(6)},'
        '${station.lat.toStringAsFixed(6)},${station.name}',
    'mode': 'ride',
    'coordinate': 'gaode',
  });
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showFailure(context);
    }
  } catch (_) {
    if (context.mounted) _showFailure(context);
  }
}

void _showFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('无法打开高德导航')),
  );
}
