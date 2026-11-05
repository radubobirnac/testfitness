import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/services/rest_preferences_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';

/// Profile row subtitle for the rest timer.
String restTimerSummary({required bool smartRest, required int seconds}) =>
    smartRest
        ? 'Smart · by exercise type'
        : 'Same for every exercise · ${RestPreferencesService.format(seconds)}';

/// Bottom-sheet body for Settings > Rest timer: the "Smart rest" switch
/// (stored by [UserPreferencesService]) and, when it is off, the global rest
/// slider (stored through [AppBloc]).
class RestTimerSettingsSheet extends StatefulWidget {
  const RestTimerSettingsSheet({
    super.key,
    required this.initialSmartRest,
    required this.onSmartRestChanged,
  });

  final bool initialSmartRest;
  final Future<void> Function(bool enabled) onSmartRestChanged;

  /// Opens the sheet. Keeps [AppBloc] reachable from the sheet's route.
  static Future<void> show(
    BuildContext context, {
    required bool smartRest,
    required Future<void> Function(bool enabled) onSmartRestChanged,
  }) {
    final bloc = context.read<AppBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RestTimerSettingsSheet(
          initialSmartRest: smartRest,
          onSmartRestChanged: onSmartRestChanged,
        ),
      ),
    );
  }

  @override
  State<RestTimerSettingsSheet> createState() => _RestTimerSettingsSheetState();
}

class _RestTimerSettingsSheetState extends State<RestTimerSettingsSheet> {
  late bool _smartRest = widget.initialSmartRest;

  Future<void> _setSmartRest(bool enabled) async {
    setState(() => _smartRest = enabled);
    await widget.onSmartRestChanged(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = RestPreferencesService.format;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppInsets.page,
            child: Text('Rest timer', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: Gap.sm),
          SwitchListTile(
            key: const ValueKey('smart-rest-switch'),
            title: const Text('Smart rest by exercise type'),
            subtitle: Text(
              'Heavy barbell ${fmt(RestPreferencesService.heavyCompoundSeconds)}'
              ' · compounds ${fmt(RestPreferencesService.compoundSeconds)}'
              ' · machine/cable ${fmt(RestPreferencesService.machineSeconds)}'
              ' · isolation ${fmt(RestPreferencesService.isolationSeconds)}',
            ),
            value: _smartRest,
            onChanged: _setSmartRest,
          ),
          if (!_smartRest)
            BlocBuilder<AppBloc, AppState>(
              builder: (context, state) {
                final seconds = state.preferences[
                        UserPreferencesService.restTimerDurationKey] as int? ??
                    UserPreferencesService().getRestTimerDuration();
                final value = seconds.clamp(15, 300).toDouble();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, Gap.sm, Gap.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Rest for every exercise',
                                style: theme.textTheme.bodyLarge),
                          ),
                          Text(
                            fmt(seconds),
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      Slider(
                        key: const ValueKey('global-rest-slider'),
                        min: 15,
                        max: 300,
                        divisions: 57,
                        value: value,
                        label: fmt(value.round()),
                        onChanged: (v) => context.read<AppBloc>().add(
                              AppPreferencesUpdated({
                                UserPreferencesService.restTimerDurationKey:
                                    v.round(),
                              }),
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, 0),
            child: Text(
              'You can still set rest per exercise from the Rest chip in a '
              'workout.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
