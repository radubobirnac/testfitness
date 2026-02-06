// This file uses conditional exports to select the correct implementation
// based on the platform at compile time.

// The conditional export is the magic that makes this work:
// - On web platforms, it uses database_impl_web.dart
// - On non-web platforms where dart:io is available (mobile, desktop),
//   it uses database_impl_mobile.dart

// The compiler will only include the appropriate implementation
// in the build, avoiding trying to compile web-specific code on mobile.

export 'database_impl_web.dart'
    if (dart.library.io) 'database_impl_mobile.dart';
