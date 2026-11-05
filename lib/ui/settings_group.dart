import 'package:flutter/material.dart';
import 'package:testfitness/ui/app_ui.dart';

/// A settings section: a [SectionHeader] followed by a flat card that holds
/// list rows ([ListTile], [SwitchListTile], ...), Android/iOS-settings style.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title),
        SettingsCard(child: Column(children: children)),
        const SizedBox(height: Gap.sm),
      ],
    );
  }
}

/// Flat card used for settings content (elevation 0, surfaceContainerLow,
/// 12px radius, outlineVariant border).
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: AppInsets.page,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// A labelled slider row: title with the current value on the right, then
/// the slider, then an optional helper line.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.slider,
    this.helper,
  });

  final String title;
  final String valueLabel;
  final Widget slider;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                valueLabel,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
          slider,
          if (helper != null)
            Text(
              helper!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
