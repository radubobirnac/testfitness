import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ForegroundTimerService {
  static const MethodChannel _channel =
      MethodChannel('com.testfitness/timer_service');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> start({
    required int endEpochMs,
    required int totalDurationMs,
    required int remainingMs,
  }) async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'endEpochMs': endEpochMs,
        'totalDurationMs': totalDurationMs,
        'remainingMs': remainingMs,
      });
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update({
    required int endEpochMs,
    required int totalDurationMs,
    required int remainingMs,
  }) async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('update', {
        'endEpochMs': endEpochMs,
        'totalDurationMs': totalDurationMs,
        'remainingMs': remainingMs,
      });
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stop() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isRunning() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
