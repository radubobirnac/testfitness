import 'package:flutter/material.dart';

/// Comprehensive form validation utilities for StrengthWave
class FormValidators {
  /// Validate workout name
  static String? validateWorkoutName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Workout name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Workout name must be at least 2 characters';
    }
    
    if (value.trim().length > 50) {
      return 'Workout name must be less than 50 characters';
    }
    
    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(value)) {
      return 'Workout name contains invalid characters';
    }
    
    return null;
  }

  /// Validate workout description
  static String? validateWorkoutDescription(String? value) {
    if (value != null && value.length > 200) {
      return 'Description must be less than 200 characters';
    }
    return null;
  }

  /// Validate exercise weight
  static String? validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required';
    }
    
    final weight = double.tryParse(value.trim());
    if (weight == null) {
      return 'Please enter a valid number';
    }
    
    if (weight < 0) {
      return 'Weight cannot be negative';
    }
    
    if (weight > 1000) {
      return 'Weight seems too high (max: 1000)';
    }
    
    // Check for reasonable decimal places
    final parts = value.split('.');
    if (parts.length > 1 && parts[1].length > 2) {
      return 'Weight can have at most 2 decimal places';
    }
    
    return null;
  }

  /// Validate exercise reps
  static String? validateReps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reps is required';
    }
    
    final reps = int.tryParse(value.trim());
    if (reps == null) {
      return 'Please enter a valid whole number';
    }
    
    if (reps < 1) {
      return 'Reps must be at least 1';
    }
    
    if (reps > 999) {
      return 'Reps seems too high (max: 999)';
    }
    
    return null;
  }

  /// Validate rest time in seconds
  static String? validateRestTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Rest time is optional
    }
    
    final seconds = int.tryParse(value.trim());
    if (seconds == null) {
      return 'Please enter a valid number of seconds';
    }
    
    if (seconds < 0) {
      return 'Rest time cannot be negative';
    }
    
    if (seconds > 3600) {
      return 'Rest time cannot exceed 1 hour';
    }
    
    return null;
  }

  /// Validate exercise notes
  static String? validateNotes(String? value) {
    if (value != null && value.length > 500) {
      return 'Notes must be less than 500 characters';
    }
    return null;
  }

  /// Validate timer duration in minutes
  static String? validateTimerDuration(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Duration is required';
    }
    
    final minutes = int.tryParse(value.trim());
    if (minutes == null) {
      return 'Please enter a valid number of minutes';
    }
    
    if (minutes < 1) {
      return 'Duration must be at least 1 minute';
    }
    
    if (minutes > 480) {
      return 'Duration cannot exceed 8 hours';
    }
    
    return null;
  }

  /// Sanitize text input by removing dangerous characters
  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove file system unsafe chars
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  /// Sanitize numeric input
  static String sanitizeNumeric(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[^\d.-]'), ''); // Keep only digits, dots, and minus
  }

  /// Check if a workout has valid exercises
  static String? validateWorkoutHasExercises(List<dynamic> exercises) {
    if (exercises.isEmpty) {
      return 'Workout must have at least one exercise';
    }
    return null;
  }

  /// Validate that a workout has valid sets
  static String? validateWorkoutHasSets(List<dynamic> sets) {
    if (sets.isEmpty) {
      return 'Workout must have at least one set';
    }
    return null;
  }
}

/// Enhanced TextFormField with built-in validation and styling
class ValidatedTextFormField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final Function(String)? onChanged;
  final Function(String?)? onSaved;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  const ValidatedTextFormField({
    super.key,
    this.label,
    this.hint,
    this.validator,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.onChanged,
    this.onSaved,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: enabled 
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
