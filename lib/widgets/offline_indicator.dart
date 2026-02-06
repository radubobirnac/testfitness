import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Widget that shows offline/online status
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showWhenOnline;

  const OfflineIndicator({
    super.key,
    required this.child,
    this.showWhenOnline = false,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _isOnline = true;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _checkConnectivity();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      // Assume offline if we can't check
      _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  void _listenToConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResults) {
    final isOnline =
        connectivityResults.any((result) => result != ConnectivityResult.none);

    if (_isOnline != isOnline) {
      setState(() {
        _isOnline = isOnline;
        _showIndicator = !isOnline || widget.showWhenOnline;
      });

      if (_showIndicator) {
        _animationController.forward();

        // Auto-hide online indicator after 2 seconds
        if (isOnline && widget.showWhenOnline) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isOnline) {
              _animationController.reverse().then((_) {
                if (mounted) {
                  setState(() {
                    _showIndicator = false;
                  });
                }
              });
            }
          });
        }
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection =
        Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Stack(
        children: [
          widget.child,
          if (_showIndicator)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green : Colors.red,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? 'Back online' : 'No internet connection',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple connectivity status checker
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  final List<VoidCallback> _listeners = [];

  bool get isOnline => _isOnline;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void initialize() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      final wasOnline = _isOnline;
      _isOnline = result.any((r) => r != ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        _notifyListeners();
      }
    });
  }
}

/// Mixin for widgets that need to react to connectivity changes
mixin ConnectivityAware<T extends StatefulWidget> on State<T> {
  bool get isOnline => ConnectivityService().isOnline;

  @override
  void initState() {
    super.initState();
    ConnectivityService().addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService().removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted) {
      onConnectivityChanged(isOnline);
    }
  }

  /// Override this method to handle connectivity changes
  void onConnectivityChanged(bool isOnline) {}
}

/// Widget that shows different content based on connectivity
class ConnectivityBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isOnline) builder;

  const ConnectivityBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<ConnectivityBuilder> createState() => _ConnectivityBuilderState();
}

class _ConnectivityBuilderState extends State<ConnectivityBuilder>
    with ConnectivityAware {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context, isOnline);
  }

  @override
  void onConnectivityChanged(bool isOnline) {
    setState(() {});
  }
}
