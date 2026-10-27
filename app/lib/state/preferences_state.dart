import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_store.dart';
import '../core/push_service.dart';

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.memory());
final pushServiceProvider = Provider<PushService>((ref) => PushService());

class StationPrefs {
  const StationPrefs({required this.favorites, required this.reminders});

  final Set<String> favorites;
  final Set<String> reminders;
}

final stationPrefsProvider =
    NotifierProvider<StationPrefsNotifier, StationPrefs>(
      StationPrefsNotifier.new,
    );

class StationPrefsNotifier extends Notifier<StationPrefs> {
  @override
  StationPrefs build() {
    final store = ref.watch(localStoreProvider);
    return StationPrefs(favorites: store.favorites, reminders: store.reminders);
  }

  Future<bool> toggleFavorite(String name) async {
    final added = await ref.read(localStoreProvider).toggleFavorite(name);
    state = StationPrefs(
      favorites: ref.read(localStoreProvider).favorites,
      reminders: state.reminders,
    );
    return added;
  }

  Future<bool> toggleReminder(String name) async {
    final added = await ref.read(localStoreProvider).toggleReminder(name);
    state = StationPrefs(
      favorites: state.favorites,
      reminders: ref.read(localStoreProvider).reminders,
    );
    return added;
  }
}
