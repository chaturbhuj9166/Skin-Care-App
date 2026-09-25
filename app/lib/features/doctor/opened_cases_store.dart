import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which assigned cases this doctor has already opened at least once.
/// The backend has no per-doctor "seen" flag, so the NEW badge is driven off
/// this device-local set instead of the case's age.
class OpenedCasesStore extends ChangeNotifier {
  static const _key = 'doctor_opened_cases';

  final Set<String> _opened = {};
  bool _loaded = false;

  OpenedCasesStore() {
    _load();
  }

  /// False until SharedPreferences has been read, so the badge is not flashed
  /// on every case during the first frame after a cold start.
  bool get loaded => _loaded;

  bool isOpened(String caseId) => _opened.contains(caseId);

  Future<void> _load() async {
    // Storage being unavailable only costs the badge, so never let it throw.
    try {
      final prefs = await SharedPreferences.getInstance();
      _opened.addAll(prefs.getStringList(_key) ?? const []);
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
    notifyListeners();
  }

  Future<void> markOpened(String caseId) async {
    if (!_opened.add(caseId)) return;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _opened.toList());
    } catch (_) {
      // Keep the in-memory set; it just won't survive a restart.
    }
  }
}

final openedCasesProvider = ChangeNotifierProvider<OpenedCasesStore>((ref) => OpenedCasesStore());
