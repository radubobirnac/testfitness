import 'package:flutter/material.dart';
import 'package:testfitness/ui/app_ui.dart';

/// Small building blocks for the Progress tab (flat cards, stat tiles, empty
/// hints, chart legend). Styling follows the Workouts tab's WorkoutListCard.

/// Flat card: surfaceContainerLow, 12px radius, outlineVariant border.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    this.title,
    this.caption,
    this.trailing,
    this.padding = const EdgeInsets.all(Gap.lg),
    required this.child,
  });

  final String? title;
  final String? caption;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasHeader = title != null || caption != null || trailing != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        if (caption != null)
                          Text(
                            caption!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: Gap.sm),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: Gap.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Compact metric: label, big value, optional change line.
class ProgressStatTile extends StatelessWidget {
  const ProgressStatTile({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeUp,
  });

  final String label;
  final String value;

  /// Already formatted, e.g. "↑ 10% vs last week". The arrow carries the
  /// direction so colour is only a secondary cue.
  final String? change;
  final bool? changeUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
          if (change != null)
            Text(
              change!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: changeUp == false ? scheme.error : scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// A row of equally wide stat tiles.
class ProgressStatRow extends StatelessWidget {
  const ProgressStatRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.sm),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// One-line guidance shown when a section has no data yet.
class ProgressEmptyHint extends StatelessWidget {
  const ProgressEmptyHint({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.onSurfaceVariant),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Legend entry: a short line sample (solid or dashed) plus its label, so a
/// series is identified by text and pattern, not colour alone.
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({
    super.key,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 3,
          child: dashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(width: 4, height: 3, color: color),
                  ],
                )
              : ColoredBox(color: color),
        ),
        const SizedBox(width: Gap.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Text style for chart axis labels.
TextStyle? chartAxisStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
}

/// Fixed chart height used by every Progress chart.
const double kProgressChartHeight = 200;
