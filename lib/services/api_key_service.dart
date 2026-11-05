import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Resolves the Gemini API key used by AI features.
///
/// Keys are never bundled with the app. Resolution order:
///  1. A key the user saved on this device (Profile -> AI settings).
///  2. Debug builds only: a compile-time key passed with
///     `flutter run --dart-define=GEMINI_API_KEY=...`.
///
/// Release builds never read a compile-time key. A production app should
/// route AI calls through a backend proxy instead of holding keys on-device.
class ApiKeyService {
  static final ApiKeyService _instance = ApiKeyService._internal();
  factory ApiKeyService() => _instance;
  ApiKeyService._internal();

  static const String _prefsKey = 'gemini_api_key';

  /// Message shown when AI features are used without a configured key.
  static const String missingKeyMessage =
      'AI features need a Gemini API key. Add one in Profile → AI settings.';

  String? _userKey;
  bool _loaded = false;

  /// Notifies listeners whenever the saved key changes.
  final ValueNotifier<int> keyVersion = ValueNotifier<int>(0);

  static String? get _debugKey {
    if (!kDebugMode) return null;
    const key = String.fromEnvironment('GEMINI_API_KEY');
    return key.isEmpty ? null : key;
  }

  /// Load the saved key from device storage. Safe to call multiple times.
  Future<void> initialize() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _userKey = (stored == null || stored.trim().isEmpty) ? null : stored;
    } catch (error) {
      AppLogger.error('Failed to load saved Gemini API key', error);
    }
    _loaded = true;
  }

  /// Synchronous view of the current key (valid after [initialize]).
  String? get cachedKey => _userKey ?? _debugKey;

  Future<String?> getGeminiKey() async {
    await initialize();
    return cachedKey;
  }

  Future<bool> hasGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.isNotEmpty;
  }

  /// Save (or clear, when [key] is null/empty) the user's key on this device.
  Future<void> setGeminiKey(String? key) async {
    final trimmed = key?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
      _userKey = null;
    } else {
      await prefs.setString(_prefsKey, trimmed);
      _userKey = trimmed;
    }
    _loaded = true;
    keyVersion.value++;
  }
}
