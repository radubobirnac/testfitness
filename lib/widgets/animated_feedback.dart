import 'package:flutter/material.dart';

/// Short, unobtrusive feedback: a compact pill at the top of the screen
/// (success / error / info) or a throttled snackbar.
///
/// The pill shows one message at a time, slides in gently, disappears on its
/// own (success 2 s, info 3 s, error 4 s) and goes away as soon as it is
/// tapped or swiped. The same message is not repeated within 2 s.
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

  static void _showPill(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color Function(ColorScheme) accent,
    required Duration duration,
  }) {
    if (!context.mounted) return;
    if (!_shouldShow(
        message, _lastOverlayMessage, _lastOverlayAt, _dedupeWindow)) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _dismissActiveOverlay();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FeedbackPill(
        message: message,
        icon: icon,
        accent: accent,
        duration: duration,
        onDismissed: () {
          if (_activeOverlay == entry) {
            _activeOverlay = null;
            entry.remove();
          }
        },
      ),
    );
    _activeOverlay = entry;
    _lastOverlayMessage = message;
    _lastOverlayAt = DateTime.now();
    overlay.insert(entry);
  }

  /// Brief confirmation for something the screen does not already show.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) =>
      _showPill(context, message,
          icon: Icons.check_circle_rounded,
          accent: (c) => Colors.green.shade400,
          duration: duration);

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) =>
      _showPill(context, message,
          icon: Icons.error_rounded,
          accent: (c) => Colors.red.shade300,
          duration: duration);

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      _showPill(context, message,
          icon: Icons.info_rounded,
          accent: (c) => Colors.lightBlue.shade300,
          duration: duration);

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
    _lastSnackMessage = message;
    _lastSnackAt = DateTime.now();
  }
}

class _FeedbackPill extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color Function(ColorScheme) accent;
  final Duration duration;
  final VoidCallback onDismissed;

  const _FeedbackPill({
    required this.message,
    required this.icon,
    required this.accent,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_FeedbackPill> createState() => _FeedbackPillState();
}

class _FeedbackPillState extends State<_FeedbackPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
    vsync: this,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(_curve),
            child: Semantics(
              liveRegion: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                onVerticalDragStart: (_) => _dismiss(),
                onHorizontalDragStart: (_) => _dismiss(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (MediaQuery.sizeOf(context).width - 32)
                        .clamp(0.0, 420.0),
                  ),
                  child: Material(
                    color: scheme.inverseSurface,
                    elevation: 3,
                    shape: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon,
                              size: 18, color: widget.accent(scheme)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onInverseSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
