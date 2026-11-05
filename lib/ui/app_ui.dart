import 'package:flutter/material.dart';

/// Shared layout primitives: one spacing scale, one page inset and one
/// section header so screens stay visually consistent.
///
/// Rules (see the Workouts tab for the reference implementation):
/// - one primary action per screen; secondary actions go in a sheet or menu;
/// - headers scroll with the content (CustomScrollView + slivers);
/// - card title = titleMedium (1 line), meta = bodySmall onSurfaceVariant;
/// - colours only from [ColorScheme], text only from [TextTheme];
/// - interactive controls are at least 48dp.

/// Spacing scale in logical pixels.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class AppInsets {
  /// Horizontal page gutter.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: Gap.lg);
}

/// Minimum interactive size (Material accessibility guideline).
const double kMinTouchTarget = 48;

/// Small, scrolling section label ("Planned", "This week", "Routines") with
/// an optional trailing action such as a [TextButton] or [IconButton].
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: trailing == null ? 0 : kMinTouchTarget,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
