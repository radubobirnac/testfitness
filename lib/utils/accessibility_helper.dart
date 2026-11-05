import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility helper utilities for StrengthWave
class AccessibilityHelper {
  
  /// Create semantic label for workout card
  static String workoutCardSemantics({
    required String workoutName,
    required int exerciseCount,
    required int setCount,
    required bool isCompleted,
    String? scheduledDate,
    String? completedDate,
  }) {
    final buffer = StringBuffer();
    buffer.write('Workout: $workoutName. ');
    buffer.write('$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}. ');
    buffer.write('$setCount ${setCount == 1 ? 'set' : 'sets'}. ');
    
    if (isCompleted) {
      buffer.write('Completed');
      if (completedDate != null) {
        buffer.write(' on $completedDate');
      }
    } else {
      buffer.write('Not completed');
      if (scheduledDate != null) {
        buffer.write('. Scheduled for $scheduledDate');
      }
    }
    
    buffer.write('. Double tap to edit.');
    return buffer.toString();
  }

  /// Create semantic label for exercise set
  static String exerciseSetSemantics({
    required String exerciseName,
    required int setNumber,
    required int reps,
    required double weight,
    required String weightUnit,
    bool isCompleted = false,
  }) {
    return 'Set $setNumber of $exerciseName. $reps repetitions at $weight $weightUnit. ${isCompleted ? 'Completed' : 'Not completed'}.';
  }

  /// Create semantic label for progress chart
  static String progressChartSemantics({
    required String chartType,
    required String timeRange,
    required String summary,
  }) {
    return '$chartType chart for $timeRange. $summary';
  }

  /// Create semantic label for goal progress
  static String goalProgressSemantics({
    required String goalTitle,
    required double progressPercentage,
    required String targetValue,
    required String unit,
    required int daysRemaining,
  }) {
    final buffer = StringBuffer();
    buffer.write('Goal: $goalTitle. ');
    buffer.write('Progress: ${progressPercentage.toStringAsFixed(1)}% complete. ');
    buffer.write('Target: $targetValue $unit. ');
    
    if (daysRemaining > 0) {
      buffer.write('$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} remaining.');
    } else {
      buffer.write('Goal deadline has passed.');
    }
    
    return buffer.toString();
  }

  /// Create semantic label for timer
  static String timerSemantics({
    required Duration remaining,
    required bool isRunning,
    required bool isPaused,
  }) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    final buffer = StringBuffer();
    buffer.write('Timer: ');
    
    if (minutes > 0) {
      buffer.write('$minutes ${minutes == 1 ? 'minute' : 'minutes'} ');
    }
    buffer.write('$seconds ${seconds == 1 ? 'second' : 'seconds'} ');
    
    if (isRunning) {
      buffer.write('remaining');
    } else if (isPaused) {
      buffer.write('paused');
    } else {
      buffer.write('stopped');
    }
    
    return buffer.toString();
  }

  /// Create accessible button with proper semantics
  static Widget accessibleButton({
    required Widget child,
    required VoidCallback? onPressed,
    required String semanticLabel,
    String? tooltip,
    bool excludeSemantics = false,
  }) {
    Widget button = ElevatedButton(
      onPressed: onPressed,
      child: child,
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: excludeSemantics,
      child: button,
    );
  }

  /// Create accessible icon button
  static Widget accessibleIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String semanticLabel,
    String? tooltip,
    Color? color,
    double? size,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
        tooltip: tooltip ?? semanticLabel,
      ),
    );
  }

  /// Create accessible text field
  static Widget accessibleTextField({
    required TextEditingController? controller,
    required String label,
    String? hint,
    String? semanticLabel,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Semantics(
      label: semanticLabel ?? '$label text field',
      textField: true,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  /// Create accessible slider
  static Widget accessibleSlider({
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
    required String semanticLabel,
    String? unit,
    int? divisions,
  }) {
    return Semantics(
      label: semanticLabel,
      value: '${value.toStringAsFixed(1)} ${unit ?? ''}',
      increasedValue: '${(value + (max - min) / (divisions ?? 10)).toStringAsFixed(1)} ${unit ?? ''}',
      decreasedValue: '${(value - (max - min) / (divisions ?? 10)).toStringAsFixed(1)} ${unit ?? ''}',
      slider: true,
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        label: '${value.toStringAsFixed(1)} ${unit ?? ''}',
      ),
    );
  }

  /// Create accessible switch
  static Widget accessibleSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String label,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? label,
      toggled: value,
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Create accessible progress indicator
  static Widget accessibleProgressIndicator({
    required double progress,
    required String label,
    String? semanticLabel,
    Color? color,
  }) {
    final percentage = (progress * 100).toStringAsFixed(1);
    
    return Semantics(
      label: semanticLabel ?? '$label: $percentage% complete',
      value: '$percentage%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text('$percentage%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Announce message to screen reader
  static void announceMessage(String message) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  }

  /// Check if screen reader is enabled
  static bool get isScreenReaderEnabled {
    return WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.accessibleNavigation;
  }

  /// Get recommended minimum touch target size
  static double get minimumTouchTargetSize => 48.0;

  /// Create accessible card with proper semantics
  static Widget accessibleCard({
    required Widget child,
    required String semanticLabel,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
    );
  }

  /// Create accessible list tile
  static Widget accessibleListTile({
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    required String semanticLabel,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        selected: selected,
      ),
    );
  }
}

/// Accessibility theme extensions
class AccessibilityTheme {
  /// Get high contrast theme
  static ThemeData getHighContrastTheme(BuildContext context) {
    final base = Theme.of(context);
    
    return base.copyWith(
      colorScheme: const ColorScheme.highContrastLight(),
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 18, // Larger text
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 48), // Larger touch targets
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
      iconTheme: base.iconTheme.copyWith(
        size: 28, // Larger icons
      ),
    );
  }

  /// Get large text theme
  static ThemeData getLargeTextTheme(BuildContext context) {
    final base = Theme.of(context);
    
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(fontSize: 64),
        displayMedium: base.textTheme.displayMedium?.copyWith(fontSize: 52),
        displaySmall: base.textTheme.displaySmall?.copyWith(fontSize: 44),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(fontSize: 40),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 36),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 32),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 28),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 24),
        titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 20),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 20),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 18),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 16),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 18),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 16),
        labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 14),
      ),
    );
  }
}
