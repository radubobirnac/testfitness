import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:testfitness/widgets/app_version_text.dart';

void main() {
  testWidgets('shows version and build number', (tester) async {
    final info = PackageInfo(
      appName: 'StrengthWave',
      packageName: 'com.radubobirnac.testfitness',
      version: '1.1.0',
      buildNumber: '2',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppVersionText(loader: () async => info)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('StrengthWave 1.1.0 (build 2)'), findsOneWidget);
  });
}
