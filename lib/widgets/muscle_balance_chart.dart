import 'package:flutter/material.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_widgets.dart';

/// Sets per muscle group as labelled horizontal bars. Replaces the old
/// colour-coded pie chart: every row carries its name and number, so it
/// reads the same without colour.
class MuscleBalanceChart extends StatelessWidget {
  const MuscleBalanceChart({
    super.key,
    required this.entries,
    required this.caption,
    this.maxRows = 8,
  });

  /// Muscle group → sets, largest first.
  final List<MapEntry<String, int>> entries;
  final String caption;
  final int maxRows;

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = entries.take(maxRows).toList();
    final max = rows.isEmpty ? 1 : rows.first.value;

    return ProgressCard(
      title: 'Sets per muscle group',
      caption: caption,
      child: Column(
        children: [
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Semantics(
                label: '${_titleCase(e.key)}: ${e.value} sets',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleCase(e.key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${e.value} sets',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : e.value / max,
                        minHeight: 8,
                        color: scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (entries.length > maxRows)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '+${entries.length - maxRows} more',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
