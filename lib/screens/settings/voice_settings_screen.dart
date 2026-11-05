import 'package:flutter/material.dart';
import 'package:testfitness/services/enhanced_tts_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/settings_group.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Defaults used by [EnhancedTTSService] when nothing is stored (kept in sync
/// with its `_loadSettings`).
const double kDefaultSpeechRate = 0.6;
const double kDefaultSpeechPitch = 1.1;
const bool kDefaultMotivationalPhrases = false;

/// One-line summary of the voice settings, used as the Profile row subtitle.
String voiceSettingsSummary(EnhancedTTSService tts) {
  final voice = tts.selectedVoice.isEmpty ? 'Default voice' : tts.selectedVoice;
  return '$voice · rate ${(tts.speechRate * 100).round()}%';
}

/// Settings > Voice & speech: rate, pitch, motivational phrases, voice
/// selection and test buttons. All values are stored by
/// [EnhancedTTSService].
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final EnhancedTTSService _tts = EnhancedTTSService();

  /// True once the TTS engine is ready; voice controls are disabled before.
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _tts.initialize();
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      AppLogger.error('VoiceSettingsScreen: TTS initialization failed', e);
    }
  }

  /// Apply a TTS setting change; errors are logged, never thrown into the UI.
  Future<void> _apply(Future<void> Function() change) async {
    try {
      await change();
    } catch (e) {
      AppLogger.error('VoiceSettingsScreen: TTS setting failed', e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _resetToDefaults() async {
    await _apply(() async {
      await _tts.setSpeechRate(kDefaultSpeechRate);
      await _tts.setPitch(kDefaultSpeechPitch);
      await _tts.setUseMotivationalPhrases(kDefaultMotivationalPhrases);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice settings reset to defaults')),
    );
  }

  void _showVoiceSelectionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Voice'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _tts.availableVoices.isEmpty
              ? const Center(child: Text('No voices available'))
              : ListView.builder(
                  itemCount: _tts.availableVoices.length,
                  itemBuilder: (context, index) {
                    final voice = _tts.availableVoices[index];
                    final voiceName = voice['name'] ?? 'Unknown';
                    final locale = voice['locale'] ?? '';
                    final isSelected = voiceName == _tts.selectedVoice;
                    return ListTile(
                      title: Text(voiceName),
                      subtitle: Text(locale),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () async {
                        final navigator = Navigator.of(dialogContext);
                        await _tts.setVoice(voiceName);
                        if (mounted) {
                          setState(() {});
                          navigator.pop();
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = _tts.speechRate.clamp(0.3, 1.5).toDouble();
    final pitch = _tts.pitch.clamp(0.5, 2.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Voice & speech')),
      body: ListView(
        padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xl),
        children: [
          SettingsGroup(
            title: 'Voice',
            children: [
              SettingsSlider(
                title: 'Speech rate',
                valueLabel: '${(_tts.speechRate * 100).round()}%',
                slider: Slider(
                  key: const ValueKey('tts-rate-slider'),
                  min: 0.3,
                  max: 1.5,
                  value: rate,
                  onChanged: _ttsReady
                      ? (v) => _apply(() => _tts.setSpeechRate(v))
                      : null,
                ),
              ),
              SettingsSlider(
                title: 'Voice pitch',
                valueLabel: '${(_tts.pitch * 100).round()}%',
                slider: Slider(
                  key: const ValueKey('tts-pitch-slider'),
                  min: 0.5,
                  max: 2.0,
                  value: pitch,
                  onChanged: _ttsReady
                      ? (v) => _apply(() => _tts.setPitch(v))
                      : null,
                ),
              ),
              SwitchListTile(
                key: const ValueKey('tts-motivational-switch'),
                title: const Text('Motivational phrases'),
                value: _tts.useMotivationalPhrases,
                onChanged: _ttsReady
                    ? (v) => _apply(() => _tts.setUseMotivationalPhrases(v))
                    : null,
              ),
              ListTile(
                key: const ValueKey('tts-select-voice'),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Select Voice'),
                subtitle: Text(
                  _tts.selectedVoice.isEmpty
                      ? 'Device default'
                      : _tts.selectedVoice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showVoiceSelectionDialog,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Test',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _tts.testVoice(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Test Voice'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _tts.testBoxingVoice(),
                      icon: const Icon(Icons.sports_martial_arts),
                      label: const Text('Boxing'),
                    ),
                    FilledButton.tonalIcon(
                      // Timer completion message with the current settings.
                      onPressed: () => _tts.speak(
                        'Timer complete! Time for your next set!',
                        context: 'timer_completion',
                      ),
                      icon: const Icon(Icons.timer),
                      label: const Text('Timer'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('tts-stop-all'),
                      onPressed: () => _tts.stop(),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop All'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Center(
            child: TextButton.icon(
              key: const ValueKey('voice-settings-reset'),
              style: TextButton.styleFrom(
                  minimumSize: const Size(kMinTouchTarget, kMinTouchTarget)),
              onPressed: _ttsReady ? _resetToDefaults : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to defaults'),
            ),
          ),
        ],
      ),
    );
  }
}
