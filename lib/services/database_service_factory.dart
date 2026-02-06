import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database/database_impl.dart';

/// Factory for creating the appropriate database service based on platform
class DatabaseServiceFactory {
  /// Get the appropriate database service for the current platform
  static DatabaseInterface getDatabaseService() {
    // We're now using the conditionally imported DatabaseImpl,
    // which automatically selects the right implementation at compile time
    return DatabaseImpl();
  }

  /// Initialize the database service
  static Future<void> initialize() async {
    // Initialize the database
    await DatabaseImpl().initialize();
  }
}
