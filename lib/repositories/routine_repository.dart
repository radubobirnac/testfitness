import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Stores routines as a JSON list in shared_preferences ('routines_v1').
/// Works on web and mobile without a database migration.
class RoutineRepository {
  static const String storageKey = 'routines_v1';

  /// Bumped after every write so open screens can reload their routines.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Most recently used first, then newest created.
  Future<List<Routine>> getRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final routines = decoded
          .whereType<Map>()
          .map((e) => Routine.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      routines.sort((a, b) {
        final aDate = a.lastUsedAt ?? a.createdAt;
        final bDate = b.lastUsedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
      return routines;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to read routines', e, stackTrace);
      return [];
    }
  }

  /// Inserts or replaces (by id).
  Future<void> saveRoutine(Routine r) async {
    final routines = await getRoutines();
    final index = routines.indexWhere((e) => e.id == r.id);
    if (index >= 0) {
      routines[index] = r;
    } else {
      routines.add(r);
    }
    await _write(routines);
  }

  Future<void> deleteRoutine(String id) async {
    final routines = await getRoutines();
    routines.removeWhere((e) => e.id == id);
    await _write(routines);
  }

  Future<void> markUsed(String id) async {
    final routines = await getRoutines();
    final index = routines.indexWhere((e) => e.id == id);
    if (index < 0) return;
    routines[index] = routines[index].copyWith(lastUsedAt: DateTime.now());
    await _write(routines);
  }

  Future<void> _write(List<Routine> routines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(routines.map((r) => r.toJson()).toList()),
    );
    changes.value++;
  }
}
