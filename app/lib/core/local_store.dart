import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStore {
  LocalStore._(this._prefs, this.deviceId, this._favorites, this._reminders);

  static const _deviceKey = 'zju_charger_device_id';
  static const _favoritesKey = 'zju_charger_favorites';
  static const _remindersKey = 'zju_charger_reminders';

  final SharedPreferences? _prefs;
  final String deviceId;
  final Set<String> _favorites;
  final Set<String> _reminders;

  Set<String> get favorites => Set.unmodifiable(_favorites);
  Set<String> get reminders => Set.unmodifiable(_reminders);

  static Future<LocalStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceKey, deviceId);
    }
    return LocalStore._(
      prefs,
      deviceId,
      prefs.getStringList(_favoritesKey)?.toSet() ?? <String>{},
      prefs.getStringList(_remindersKey)?.toSet() ?? <String>{},
    );
  }

  factory LocalStore.memory() {
    return LocalStore._(null, const Uuid().v4(), <String>{}, <String>{});
  }

  Future<bool> toggleFavorite(String name) async {
    final added = !_favorites.remove(name);
    if (added) _favorites.add(name);
    await _prefs?.setStringList(_favoritesKey, _favorites.toList()..sort());
    return added;
  }

  Future<bool> toggleReminder(String name) async {
    final added = !_reminders.remove(name);
    if (added) _reminders.add(name);
    await _prefs?.setStringList(_remindersKey, _reminders.toList()..sort());
    return added;
  }

  Future<void> setReminders(Set<String> names) async {
    _reminders
      ..clear()
      ..addAll(names);
    await _prefs?.setStringList(_remindersKey, _reminders.toList()..sort());
  }
}
