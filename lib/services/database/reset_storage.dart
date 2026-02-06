// This file uses conditional exports to provide the appropriate implementation
// based on the platform being compiled for.

// Export the mobile/desktop implementation by default
export 'reset_storage_mobile.dart'
    if (dart.library.html) 'reset_storage_web.dart';
