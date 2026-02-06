import 'package:testfitness/models/workout.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Service for tracking total weight lifted over time
class WeightTrackingService {
  /// Calculate total weight lifted for a single workout
  static double calculateWorkoutTotalWeight(Workout workout) {
    if (!workout.isCompleted || workout.sets.isEmpty) {
      return 0.0;
    }

    double totalWeight = 0.0;
    for (final set in workout.sets) {
      // Total weight = weight × reps for each set
      totalWeight += (set.weight * set.reps);
    }

    AppLogger.debug(
        'Workout "${workout.name}" total weight: ${totalWeight.toStringAsFixed(1)} lbs');
    return totalWeight;
  }

  /// Calculate total weight lifted across multiple workouts
  static double calculateTotalWeightLifted(List<Workout> workouts) {
    final completedWorkouts = workouts.where((w) => w.isCompleted).toList();

    double grandTotal = 0.0;
    for (final workout in completedWorkouts) {
      grandTotal += calculateWorkoutTotalWeight(workout);
    }

    AppLogger.info(
        'Total weight lifted across ${completedWorkouts.length} workouts: ${grandTotal.toStringAsFixed(1)} lbs');
    return grandTotal;
  }

  /// Get weight lifted data grouped by time period
  static Map<String, double> getWeightLiftedByPeriod(
    List<Workout> workouts,
    WeightTrackingPeriod period,
  ) {
    final completedWorkouts = workouts
        .where((w) => w.isCompleted && w.completedDate != null)
        .toList();

    // Sort by completion date
    completedWorkouts
        .sort((a, b) => a.completedDate!.compareTo(b.completedDate!));

    final Map<String, double> periodData = {};
    final now = DateTime.now();

    for (final workout in completedWorkouts) {
      final completedDate = workout.completedDate!;
      String periodKey;

      switch (period) {
        case WeightTrackingPeriod.daily:
          // Last 7 days
          final daysDiff = now.difference(completedDate).inDays;
          if (daysDiff >= 0 && daysDiff < 7) {
            periodKey = _formatDate(completedDate, 'MM/dd');
          } else {
            continue; // Skip workouts older than 7 days
          }
          break;

        case WeightTrackingPeriod.weekly:
          // Last 8 weeks
          final weeksDiff = now.difference(completedDate).inDays ~/ 7;
          if (weeksDiff >= 0 && weeksDiff < 8) {
            final weekStart = completedDate
                .subtract(Duration(days: completedDate.weekday - 1));
            periodKey = _formatDate(weekStart, 'MM/dd');
          } else {
            continue; // Skip workouts older than 8 weeks
          }
          break;

        case WeightTrackingPeriod.monthly:
          // Last 12 months
          final monthsDiff = (now.year - completedDate.year) * 12 +
              (now.month - completedDate.month);
          if (monthsDiff >= 0 && monthsDiff < 12) {
            periodKey = _formatDate(completedDate, 'MMM yyyy');
          } else {
            continue; // Skip workouts older than 12 months
          }
          break;
      }

      final workoutWeight = calculateWorkoutTotalWeight(workout);
      periodData[periodKey] = (periodData[periodKey] ?? 0.0) + workoutWeight;
    }

    AppLogger.debug(
        'Weight tracking for ${period.name}: ${periodData.length} periods with data');
    return periodData;
  }

  /// Get cumulative weight lifted over time
  static Map<String, double> getCumulativeWeightLifted(
    List<Workout> workouts,
    WeightTrackingPeriod period,
  ) {
    final periodData = getWeightLiftedByPeriod(workouts, period);
    final Map<String, double> cumulativeData = {};

    double runningTotal = 0.0;
    final sortedKeys = periodData.keys.toList()..sort();

    for (final key in sortedKeys) {
      runningTotal += periodData[key]!;
      cumulativeData[key] = runningTotal;
    }

    return cumulativeData;
  }

  /// Get weight lifted statistics
  static WeightTrackingStats getWeightTrackingStats(List<Workout> workouts) {
    final completedWorkouts = workouts.where((w) => w.isCompleted).toList();

    if (completedWorkouts.isEmpty) {
      return WeightTrackingStats(
        totalWeightLifted: 0.0,
        averagePerWorkout: 0.0,
        heaviestWorkout: 0.0,
        totalWorkouts: 0,
        bestWeek: 0.0,
        bestMonth: 0.0,
      );
    }

    final totalWeight = calculateTotalWeightLifted(completedWorkouts);
    final averagePerWorkout = totalWeight / completedWorkouts.length;

    // Find heaviest single workout
    double heaviestWorkout = 0.0;
    for (final workout in completedWorkouts) {
      final workoutWeight = calculateWorkoutTotalWeight(workout);
      if (workoutWeight > heaviestWorkout) {
        heaviestWorkout = workoutWeight;
      }
    }

    // Find best week and month
    final weeklyData =
        getWeightLiftedByPeriod(workouts, WeightTrackingPeriod.weekly);
    final monthlyData =
        getWeightLiftedByPeriod(workouts, WeightTrackingPeriod.monthly);

    final bestWeek = weeklyData.values.isEmpty
        ? 0.0
        : weeklyData.values.reduce((a, b) => a > b ? a : b);
    final bestMonth = monthlyData.values.isEmpty
        ? 0.0
        : monthlyData.values.reduce((a, b) => a > b ? a : b);

    return WeightTrackingStats(
      totalWeightLifted: totalWeight,
      averagePerWorkout: averagePerWorkout,
      heaviestWorkout: heaviestWorkout,
      totalWorkouts: completedWorkouts.length,
      bestWeek: bestWeek,
      bestMonth: bestMonth,
    );
  }

  /// Format date based on pattern
  static String _formatDate(DateTime date, String pattern) {
    switch (pattern) {
      case 'MM/dd':
        return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      case 'MMM yyyy':
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${months[date.month - 1]} ${date.year}';
      default:
        return date.toString();
    }
  }
}

/// Time period for weight tracking
enum WeightTrackingPeriod {
  daily, // Last 7 days
  weekly, // Last 8 weeks
  monthly, // Last 12 months
}

/// Weight tracking statistics
class WeightTrackingStats {
  final double totalWeightLifted;
  final double averagePerWorkout;
  final double heaviestWorkout;
  final int totalWorkouts;
  final double bestWeek;
  final double bestMonth;

  const WeightTrackingStats({
    required this.totalWeightLifted,
    required this.averagePerWorkout,
    required this.heaviestWorkout,
    required this.totalWorkouts,
    required this.bestWeek,
    required this.bestMonth,
  });

  /// Format weight with appropriate units
  String formatWeight(double weight, {bool includeUnits = true}) {
    if (weight >= 1000000) {
      return '${(weight / 1000000).toStringAsFixed(1)}${includeUnits ? 'M lbs' : 'M'}';
    } else if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(1)}${includeUnits ? 'K lbs' : 'K'}';
    } else {
      return '${weight.toStringAsFixed(0)}${includeUnits ? ' lbs' : ''}';
    }
  }
}
