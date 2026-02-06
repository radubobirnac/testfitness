import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Retry mechanism for failed operations
class RetryMechanism {
  /// Execute a function with retry logic
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (attempt <= maxRetries) {
      try {
        AppLogger.debug('${operationName ?? 'Operation'} attempt ${attempt + 1}');
        final result = await operation();
        
        if (attempt > 0) {
          AppLogger.info('${operationName ?? 'Operation'} succeeded after ${attempt + 1} attempts');
        }
        
        return result;
      } catch (error, stackTrace) {
        attempt++;
        
        AppLogger.warning(
          '${operationName ?? 'Operation'} failed on attempt $attempt: $error',
          error,
          stackTrace,
        );

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          AppLogger.error('${operationName ?? 'Operation'} failed with non-retryable error', error, stackTrace);
          rethrow;
        }

        // If this was the last attempt, throw the error
        if (attempt > maxRetries) {
          AppLogger.error('${operationName ?? 'Operation'} failed after $maxRetries retries', error, stackTrace);
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    throw StateError('This should never be reached');
  }

  /// Check if an error is retryable (network, timeout, etc.)
  static bool isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network-related errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable') ||
        errorString.contains('socket')) {
      return true;
    }

    // Database lock errors
    if (errorString.contains('database is locked') ||
        errorString.contains('busy')) {
      return true;
    }

    // Temporary server errors (5xx)
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    return false;
  }
}

/// Widget that provides retry functionality for failed operations
class RetryableOperation extends StatefulWidget {
  final Future<Widget> Function() operation;
  final Widget Function(dynamic error, VoidCallback retry)? errorBuilder;
  final Widget? loadingWidget;
  final String? operationName;
  final int maxRetries;

  const RetryableOperation({
    super.key,
    required this.operation,
    this.errorBuilder,
    this.loadingWidget,
    this.operationName,
    this.maxRetries = 3,
  });

  @override
  State<RetryableOperation> createState() => _RetryableOperationState();
}

class _RetryableOperationState extends State<RetryableOperation> {
  late Future<Widget> _future;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _executeOperation();
  }

  void _executeOperation() {
    _future = RetryMechanism.execute(
      operation: widget.operation,
      maxRetries: widget.maxRetries,
      shouldRetry: RetryMechanism.isRetryableError,
      operationName: widget.operationName,
    );
  }

  void _retry() {
    setState(() {
      _retryCount++;
      _executeOperation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? 
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return widget.errorBuilder?.call(snapshot.error!, _retry) ??
              _buildDefaultErrorWidget(snapshot.error!);
        }

        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }

  Widget _buildDefaultErrorWidget(dynamic error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              RetryMechanism.isRetryableError(error)
                  ? 'Please check your connection and try again'
                  : 'An unexpected error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: Text(_retryCount > 0 ? 'Try Again' : 'Retry'),
            ),
            if (_retryCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Retry attempt: ${_retryCount + 1}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mixin for widgets that need retry functionality
mixin RetryableMixin<T extends StatefulWidget> on State<T> {
  /// Execute an operation with retry logic and show loading/error states
  Future<R> executeWithRetry<R>({
    required Future<R> Function() operation,
    String? operationName,
    int maxRetries = 3,
    bool showLoading = true,
    bool showError = true,
  }) async {
    if (showLoading) {
      // Show loading indicator if needed
      // This could be implemented with a loading overlay
    }

    try {
      final result = await RetryMechanism.execute(
        operation: operation,
        maxRetries: maxRetries,
        shouldRetry: RetryMechanism.isRetryableError,
        operationName: operationName,
      );

      return result;
    } catch (error) {
      if (showError && mounted) {
        _showErrorSnackBar(error, operationName);
      }
      rethrow;
    }
  }

  void _showErrorSnackBar(dynamic error, String? operationName) {
    final message = RetryMechanism.isRetryableError(error)
        ? 'Connection error. Please check your internet and try again.'
        : 'An error occurred${operationName != null ? ' during $operationName' : ''}.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // The retry logic would need to be implemented by the calling widget
          },
        ),
      ),
    );
  }
}

/// Utility for database operations with retry
class DatabaseRetryHelper {
  static Future<T> executeQuery<T>({
    required Future<T> Function() query,
    String? queryName,
  }) async {
    return RetryMechanism.execute(
      operation: query,
      maxRetries: 3,
      initialDelay: const Duration(milliseconds: 100),
      maxDelay: const Duration(seconds: 2),
      shouldRetry: (error) {
        final errorString = error.toString().toLowerCase();
        return errorString.contains('database is locked') ||
               errorString.contains('busy') ||
               errorString.contains('cannot open');
      },
      operationName: queryName ?? 'Database query',
    );
  }
}
