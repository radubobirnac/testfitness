import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Small "StrengthWave 1.1.0 (build 2)" line, so you can tell which build is
/// installed. The version comes from pubspec.yaml at build time.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key, this.loader});

  /// Injectable for tests; defaults to [PackageInfo.fromPlatform].
  final Future<PackageInfo> Function()? loader;

  static String format(PackageInfo info) =>
      'StrengthWave ${info.version} (build ${info.buildNumber})';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: (loader ?? PackageInfo.fromPlatform)(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Center(
          child: Text(
            format(info),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
