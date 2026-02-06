import 'package:flutter/material.dart';

/// Animated feedback widget for success/error states
class AnimatedFeedback {
  static const Duration _dedupeWindow = Duration(seconds: 2);
  static OverlayEntry? _activeOverlay;
  static String? _lastOverlayMessage;
  static DateTime? _lastOverlayAt;
  static String? _lastSnackMessage;
  static DateTime? _lastSnackAt;

  static bool _shouldShow(
    String message,
    String? lastMessage,
    DateTime? lastAt,
    Duration window,
  ) {
    if (lastMessage == null || lastAt == null) return true;
    if (message != lastMessage) return true;
    return DateTime.now().difference(lastAt) > window;
  }

  static void _dismissActiveOverlay() {
    _activeOverlay?.remove();
    _activeOverlay = null;
  }

  static void _trackOverlay(String message) {
    _lastOverlayMessage = message;
    _lastOverlayAt = DateTime.now();
  }

  static void _trackSnack(String message) {
    _lastSnackMessage = message;
    _lastSnackAt = DateTime.now();
  }

  /// Show animated success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    if (!_shouldShow(message, _lastOverlayMessage, _lastOverlayAt, _dedupeWindow)) {
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    _dismissActiveOverlay();
    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedFeedbackWidget(
        message: message,
        icon: Icons.check_circle,
        color: Colors.green,
        onDismiss: () {
          if (_activeOverlay == overlayEntry) {
            _activeOverlay = null;
          }
          overlayEntry.remove();
        },
        duration: duration,
      ),
    );

    _activeOverlay = overlayEntry;
    _trackOverlay(message);
    overlay.insert(overlayEntry);
  }

  /// Show animated error message
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    if (!_shouldShow(message, _lastOverlayMessage, _lastOverlayAt, _dedupeWindow)) {
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    _dismissActiveOverlay();
    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedFeedbackWidget(
        message: message,
        icon: Icons.error,
        color: Colors.red,
        onDismiss: () {
          if (_activeOverlay == overlayEntry) {
            _activeOverlay = null;
          }
          overlayEntry.remove();
        },
        duration: duration,
      ),
    );

    _activeOverlay = overlayEntry;
    _trackOverlay(message);
    overlay.insert(overlayEntry);
  }

  /// Show animated info message
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    if (!_shouldShow(message, _lastOverlayMessage, _lastOverlayAt, _dedupeWindow)) {
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    _dismissActiveOverlay();
    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedFeedbackWidget(
        message: message,
        icon: Icons.info,
        color: Colors.blue,
        onDismiss: () {
          if (_activeOverlay == overlayEntry) {
            _activeOverlay = null;
          }
          overlayEntry.remove();
        },
        duration: duration,
      ),
    );

    _activeOverlay = overlayEntry;
    _trackOverlay(message);
    overlay.insert(overlayEntry);
  }

  /// Show a throttled snackbar message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    if (!_shouldShow(message, _lastSnackMessage, _lastSnackAt, _dedupeWindow)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
    _trackSnack(message);
  }
}

class _AnimatedFeedbackWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;
  final Duration duration;

  const _AnimatedFeedbackWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_AnimatedFeedbackWidget> createState() => _AnimatedFeedbackWidgetState();
}

class _AnimatedFeedbackWidgetState extends State<_AnimatedFeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _slideController.forward();
    _scaleController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _slideController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
