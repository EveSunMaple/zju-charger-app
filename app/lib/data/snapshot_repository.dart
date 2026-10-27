import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/snapshot.dart';

class SnapshotRepository {
  const SnapshotRepository({this.apiBaseUrl = ''});

  static const assetPath = 'assets/data/snapshot.json';

  final String apiBaseUrl;

  Future<ChargerSnapshot?> fetchApi() async {
    final base = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse('$base/v1/snapshot'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ChargerSnapshot.fromJson(decoded, source: 'api');
    } catch (_) {
      return null;
    }
  }

  Future<ChargerSnapshot> load() async {
    final remote = await fetchApi();
    if (remote != null) return remote;
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ChargerSnapshot.fromJson(json);
  }
}
