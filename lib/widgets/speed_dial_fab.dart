import 'package:flutter/material.dart';

class SpeedDialFAB extends StatefulWidget {
  final Function() onEmptyTrainingTap;
  final Function() onQuickWorkoutTap;

  const SpeedDialFAB({
    super.key,
    required this.onEmptyTrainingTap,
    required this.onQuickWorkoutTap,
  });

  @override
  State<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  // Animation controller for rotating the FAB
  late AnimationController _animationController;
  // Whether the speed dial is open or closed
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toggle the speed dial
  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Option 2: Quick Workout
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.translationValues(
            0,
            _isOpen ? -160.0 : 0,
            0,
          ),
          child: _isOpen
              ? Container(
                  margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Quick Workout',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button
                      FloatingActionButton.small(
                        heroTag: 'quickWorkout',
                        onPressed: () {
                          _toggle();
                          widget.onQuickWorkoutTap();
                        },
                        child: const Icon(Icons.bolt),
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
        ),

        // Option 1: Empty Training
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.translationValues(
            0,
            _isOpen ? -90.0 : 0,
            0,
          ),
          child: _isOpen
              ? Container(
                  margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Empty Training',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button
                      FloatingActionButton.small(
                        heroTag: 'emptyTraining',
                        onPressed: () {
                          _toggle();
                          widget.onEmptyTrainingTap();
                        },
                        child: const Icon(Icons.fitness_center),
                      ),
                    ],
                  ),
                )
              : const SizedBox(),
        ),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animationController.value *
                    (3.14159 / 4), // 45 degrees in radians
                child: Icon(_isOpen ? Icons.close : Icons.add),
              );
            },
          ),
        ),
      ],
    );
  }
}
