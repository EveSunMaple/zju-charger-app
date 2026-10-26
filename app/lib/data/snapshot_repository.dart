import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/snapshot.dart';

class SnapshotRepository {
  static const assetPath = 'assets/data/snapshot.json';

  Future<ChargerSnapshot> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ChargerSnapshot.fromJson(json);
  }
}
