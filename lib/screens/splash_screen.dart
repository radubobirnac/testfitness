import 'package:flutter/material.dart';

/// A splash screen to show during app initialization
class SplashScreen extends StatelessWidget {
  final double progress;
  final String currentPhase;

  const SplashScreen({
    super.key,
    this.progress = 0.0,
    this.currentPhase = 'Starting up...',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
          primary: Colors.teal.shade600,
          secondary: Colors.teal.shade400,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon
              Image.asset(
                'assets/app_icon.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  // If the icon doesn't exist, use a fallback
                  return const Icon(
                    Icons.fitness_center,
                    color: Colors.teal,
                    size: 80,
                  );
                },
              ),
              const SizedBox(height: 32),

              // App Name
              const Text(
                'StrengthWave',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 48),

              // Progress Bar
              Container(
                width: 280,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.teal),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current phase text
                    Text(
                      currentPhase,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Progress percentage
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
