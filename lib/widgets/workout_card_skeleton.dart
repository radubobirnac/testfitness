import 'package:flutter/material.dart';

/// Skeleton loading widget for workout cards
class WorkoutCardSkeleton extends StatefulWidget {
  const WorkoutCardSkeleton({super.key});

  @override
  State<WorkoutCardSkeleton> createState() => _WorkoutCardSkeletonState();
}

class _WorkoutCardSkeletonState extends State<WorkoutCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  height: 24,
                  width: double.infinity * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: _animation.value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description skeleton
                Container(
                  height: 16,
                  width: double.infinity * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: _animation.value * 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats row skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Exercise count chip skeleton
                    Container(
                      height: 32,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: _animation.value * 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    
                    // Set count chip skeleton
                    Container(
                      height: 32,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: _animation.value * 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    
                    // Date chip skeleton
                    Container(
                      height: 32,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: _animation.value * 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Generic animated loading card for various content
class AnimatedLoadingCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const AnimatedLoadingCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<AnimatedLoadingCard> createState() => _AnimatedLoadingCardState();
}

class _AnimatedLoadingCardState extends State<AnimatedLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
