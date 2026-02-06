import 'package:flutter/material.dart';

/// A beautiful animated loading card with shimmer effect
class AnimatedLoadingCard extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const AnimatedLoadingCard({
    super.key,
    this.height = 120,
    this.width = double.infinity,
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
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton loading widget for workout cards
class WorkoutCardSkeleton extends StatelessWidget {
  const WorkoutCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title skeleton
            const AnimatedLoadingCard(
              height: 24,
              width: 200,
            ),
            const SizedBox(height: 8),

            // Description skeleton
            const AnimatedLoadingCard(
              height: 16,
              width: 150,
            ),
            const SizedBox(height: 16),

            // Stats row skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedLoadingCard(
                  height: 32,
                  width: 80,
                  borderRadius: BorderRadius.circular(16),
                ),
                AnimatedLoadingCard(
                  height: 32,
                  width: 60,
                  borderRadius: BorderRadius.circular(16),
                ),
                AnimatedLoadingCard(
                  height: 32,
                  width: 70,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton loading widget for exercise cards
class ExerciseCardSkeleton extends StatelessWidget {
  const ExerciseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: AnimatedLoadingCard(
          height: 40,
          width: 40,
          borderRadius: BorderRadius.circular(20),
        ),
        title: const AnimatedLoadingCard(
          height: 18,
          width: 120,
        ),
        subtitle: const AnimatedLoadingCard(
          height: 14,
          width: 80,
        ),
      ),
    );
  }
}
