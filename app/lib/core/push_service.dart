import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';

class PushService {
  static const _appKey = String.fromEnvironment('JPUSH_APP_KEY');
  static const _debugToken = String.fromEnvironment('DEBUG_PUSH_TOKEN');

  final ValueNotifier<String?> openedStation = ValueNotifier<String?>(null);

  String? _token;

  String? get token => _token;
  bool get configured => _appKey.isNotEmpty || _debugToken.isNotEmpty;
  bool get available => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    if (_debugToken.isNotEmpty) {
      _token = _debugToken;
      return;
    }
    if (_appKey.isEmpty) return;
    try {
      final jpush = JPush.newJPush();
      jpush.addEventHandler(
        onOpenNotification: (message) async {
          final station = _stationFromMessage(message);
          if (station != null && station.isNotEmpty) {
            openedStation.value = station;
          }
        },
      );
      jpush.setup(
        appKey: _appKey,
        channel: 'developer-default',
        production: false,
        debug: false,
      );
      if (Platform.isIOS) {
        jpush.applyPushAuthority(
          const NotificationSettingsIOS(sound: true, alert: true, badge: true),
        );
        final launch = await jpush.getLaunchAppNotification();
        final launchStation = _stationFromMessage(
          Map<String, dynamic>.from(launch),
        );
        if (launchStation != null && launchStation.isNotEmpty) {
          openedStation.value = launchStation;
        }
      } else if (Platform.isAndroid) {
        jpush.requestRequiredPermission();
      }
      for (var attempt = 0; attempt < 3; attempt++) {
        final registrationId = await jpush.getRegistrationID();
        if (registrationId.isNotEmpty) {
          _token = registrationId;
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (error) {
      debugPrint('push init failed: $error');
    }
  }

  String? _stationFromMessage(Map<String, dynamic> message) {
    final extras = message['extras'];
    Object? decoded = extras;
    if (extras is String) {
      try {
        decoded = jsonDecode(extras);
      } catch (_) {
        return null;
      }
    }
    if (decoded is Map) {
      final station = decoded['station'];
      return station?.toString();
    }
    return null;
  }

  void dispose() {
    openedStation.dispose();
  }
}
