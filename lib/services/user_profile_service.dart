import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/user_profile.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

/// Service for managing user profile data
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _profileKey = 'user_profile';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';

  UserProfile? _currentProfile;

  /// Get the current user profile
  UserProfile? get currentProfile => _currentProfile;

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasCompletedOnboardingKey) ?? false;
    } catch (error) {
      AppLogger.error('Failed to check onboarding status', error);
      return false;
    }
  }

  /// Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompletedOnboardingKey, true);
      AppLogger.info('Onboarding marked as completed');
    } catch (error) {
      AppLogger.error('Failed to mark onboarding as completed', error);
    }
  }

  /// Load user profile from storage
  Future<UserProfile?> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);
      
      if (profileJson != null) {
        final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
        _currentProfile = UserProfile.fromJson(profileMap);
        AppLogger.info('User profile loaded: ${_currentProfile?.name}, Age: ${_currentProfile?.age}');
        return _currentProfile;
      }
      
      AppLogger.info('No user profile found in storage');
      return null;
    } catch (error) {
      AppLogger.error('Failed to load user profile', error);
      return null;
    }
  }

  /// Save user profile to storage
  Future<bool> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(profile.toJson());
      await prefs.setString(_profileKey, profileJson);
      
      _currentProfile = profile;
      AppLogger.info('User profile saved: ${profile.name}, Age: ${profile.age}');
      return true;
    } catch (error) {
      AppLogger.error('Failed to save user profile', error);
      return false;
    }
  }

  /// Create a new user profile
  Future<UserProfile?> createProfile({
    required String name,
    required int age,
    required String gender,
    double? height,
    double? weight,
    int? restingHeartRate,
    String fitnessLevel = 'beginner',
  }) async {
    try {
      // Validate age
      if (age < 13 || age > 120) {
        throw ArgumentError('Age must be between 13 and 120 years');
      }

      // Validate gender
      if (!Gender.all.contains(gender)) {
        throw ArgumentError('Invalid gender value');
      }

      // Validate fitness level
      if (!FitnessLevel.all.contains(fitnessLevel)) {
        throw ArgumentError('Invalid fitness level');
      }

      // Validate resting heart rate if provided
      if (restingHeartRate != null && (restingHeartRate < 40 || restingHeartRate > 120)) {
        throw ArgumentError('Resting heart rate must be between 40 and 120 BPM');
      }

      final profile = UserProfile.createDefault(
        id: const Uuid().v4(),
        name: name,
        age: age,
        gender: gender,
      ).copyWith(
        height: height,
        weight: weight,
        restingHeartRate: restingHeartRate,
        fitnessLevel: fitnessLevel,
      );

      final success = await saveProfile(profile);
      if (success) {
        await markOnboardingCompleted();
        AppLogger.info('New user profile created successfully');
        return profile;
      } else {
        AppLogger.error('Failed to save new user profile');
        return null;
      }
    } catch (error) {
      AppLogger.error('Failed to create user profile', error);
      return null;
    }
  }

  /// Update existing user profile
  Future<bool> updateProfile(UserProfile updatedProfile) async {
    try {
      final profileWithUpdatedTime = updatedProfile.copyWith(
        lastUpdated: DateTime.now(),
      );
      
      return await saveProfile(profileWithUpdatedTime);
    } catch (error) {
      AppLogger.error('Failed to update user profile', error);
      return false;
    }
  }

  /// Update specific profile fields
  Future<bool> updateProfileFields({
    String? name,
    int? age,
    String? gender,
    double? height,
    double? weight,
    int? restingHeartRate,
    String? fitnessLevel,
  }) async {
    if (_currentProfile == null) {
      AppLogger.error('No current profile to update');
      return false;
    }

    try {
      final updatedProfile = _currentProfile!.copyWith(
        name: name,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        restingHeartRate: restingHeartRate,
        fitnessLevel: fitnessLevel,
        lastUpdated: DateTime.now(),
      );

      return await saveProfile(updatedProfile);
    } catch (error) {
      AppLogger.error('Failed to update profile fields', error);
      return false;
    }
  }

  /// Delete user profile
  Future<bool> deleteProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_hasCompletedOnboardingKey);
      
      _currentProfile = null;
      AppLogger.info('User profile deleted');
      return true;
    } catch (error) {
      AppLogger.error('Failed to delete user profile', error);
      return false;
    }
  }

  /// Get safe heart rate recommendations for current user
  Map<String, int>? getHeartRateRecommendations() {
    if (_currentProfile == null) return null;

    return {
      'maxHeartRate': _currentProfile!.maxHeartRate,
      'vo2MaxTarget': _currentProfile!.vo2MaxTargetHeartRate,
      'cardioMin': _currentProfile!.cardioTargetHeartRateMin,
      'cardioMax': _currentProfile!.cardioTargetHeartRateMax,
      'fatBurnMin': _currentProfile!.fatBurnTargetHeartRateMin,
      'fatBurnMax': _currentProfile!.fatBurnTargetHeartRateMax,
      'safeThreshold': _currentProfile!.safeHeartRateThreshold,
    };
  }

  /// Check if a heart rate is safe for the current user
  bool isHeartRateSafe(int heartRate) {
    if (_currentProfile == null) {
      AppLogger.warning('No user profile available for heart rate safety check');
      return heartRate <= 180; // Conservative fallback
    }

    return _currentProfile!.isHeartRateSafe(heartRate);
  }

  /// Get heart rate safety message for current user
  String getHeartRateSafetyMessage(int heartRate) {
    if (_currentProfile == null) {
      return 'Please set up your profile for personalized heart rate guidance';
    }

    return _currentProfile!.getHeartRateSafetyMessage(heartRate);
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await loadProfile();
      AppLogger.info('UserProfileService initialized');
    } catch (error) {
      AppLogger.error('Failed to initialize UserProfileService', error);
    }
  }
}
