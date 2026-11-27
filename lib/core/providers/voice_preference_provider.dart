import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists opt-in voice-to-text capture state and one-time privacy disclosure.
///
/// Voice capture is **off by default** so the hero mic stays hidden and
/// `RECORD_AUDIO` is never requested until the user explicitly opts in and
/// acknowledges that speech recognition uses the device's configured speech
/// service (Phase 11.2).
class VoicePreference extends ChangeNotifier {
  VoicePreference({
    bool enabled = false,
    bool disclosureAccepted = false,
  })  : _enabled = enabled,
        _disclosureAccepted = disclosureAccepted;

  static const String _enabledKey = 'voice_capture_enabled';
  static const String _disclosureKey = 'voice_disclosure_accepted';

  bool _enabled;
  bool _disclosureAccepted;

  bool get enabled => _enabled;
  bool get disclosureAccepted => _disclosureAccepted;

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> acceptDisclosure() async {
    if (_disclosureAccepted) return;
    _disclosureAccepted = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclosureKey, true);
  }

  static Future<VoicePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    return VoicePreference(
      enabled: prefs.getBool(_enabledKey) ?? false,
      disclosureAccepted: prefs.getBool(_disclosureKey) ?? false,
    );
  }
}

final voicePreferenceProvider = ChangeNotifierProvider<VoicePreference>(
  (ref) => VoicePreference(),
);
