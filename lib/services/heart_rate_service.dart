import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Service for managing heart rate monitor connections and data
class HeartRateService {
  static final HeartRateService _instance = HeartRateService._internal();
  factory HeartRateService() => _instance;
  HeartRateService._internal();

  // Bluetooth state
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<List<int>>? _heartRateSubscription;

  // Heart rate data
  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<List<BluetoothDevice>> _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();

  // Data tracking
  final List<HeartRateReading> _readings = [];
  int _currentHeartRate = 0;
  bool _isConnected = false;
  bool _isScanning = false;

  // Debug logging
  final List<String> _debugLogs = [];
  final StreamController<List<String>> _debugController =
      StreamController<List<String>>.broadcast();

  // Heart Rate Service UUID (standard Bluetooth SIG)
  static const String heartRateServiceUuid =
      "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementUuid =
      "00002a37-0000-1000-8000-00805f9b34fb";

  // Short UUID versions for comparison
  static const String heartRateServiceShortUuid = "180d";
  static const String heartRateMeasurementShortUuid = "2a37";

  // Streams
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;
  Stream<List<String>> get debugStream => _debugController.stream;

  // Getters
  int get currentHeartRate => _currentHeartRate;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String get connectedDeviceName => _connectedDevice?.platformName ?? '';
  List<HeartRateReading> get readings => List.unmodifiable(_readings);
  List<String> get debugLogs => List.unmodifiable(_debugLogs);

  /// Add debug log entry
  void _addDebugLog(String message) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logEntry = '[$timestamp] $message';
    _debugLogs.add(logEntry);

    // Keep only last 50 log entries
    if (_debugLogs.length > 50) {
      _debugLogs.removeAt(0);
    }

    // Notify listeners
    _debugController.add(List.from(_debugLogs));

    // Also log to AppLogger
    AppLogger.info(message);
  }

  /// Clear debug logs
  void clearDebugLogs() {
    _debugLogs.clear();
    _debugController.add([]);
  }

  /// Helper method to compare UUIDs (handles both short and full formats)
  bool _isUuidMatch(
      String deviceUuid, String targetFullUuid, String targetShortUuid) {
    String deviceUuidLower = deviceUuid.toLowerCase();
    bool fullMatch = deviceUuidLower == targetFullUuid.toLowerCase();
    bool shortMatch = deviceUuidLower == targetShortUuid.toLowerCase();

    _addDebugLog(
        '🔍 UUID Comparison: "$deviceUuid" vs Full:"$targetFullUuid" Short:"$targetShortUuid"');
    _addDebugLog('   📊 Full match: $fullMatch, Short match: $shortMatch');

    return fullMatch || shortMatch;
  }

  /// Initialize the heart rate service
  Future<void> initialize() async {
    try {
      AppLogger.info('Initializing Heart Rate Service');

      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        AppLogger.error('Bluetooth not supported on this device');
        return;
      }

      // Listen to Bluetooth adapter state
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        AppLogger.info('Bluetooth adapter state: $state');
        if (state != BluetoothAdapterState.on && _isConnected) {
          disconnect();
        }
      });

      AppLogger.info('Heart Rate Service initialized successfully');
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to initialize Heart Rate Service', error, stackTrace);
    }
  }

  /// Request necessary permissions for Bluetooth
  Future<bool> requestPermissions() async {
    try {
      AppLogger.info('Requesting Bluetooth permissions');

      final List<Permission> permissionsToRequest = [];

      if (Platform.isAndroid) {
        try {
          // Android 12+ runtime Bluetooth permissions.
          await Permission.bluetoothScan.status;
          await Permission.bluetoothConnect.status;
          permissionsToRequest.addAll([
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ]);
          AppLogger.info('Using Android 12+ Bluetooth permissions');
        } catch (_) {
          // Legacy Android BLE scan behavior.
          permissionsToRequest.addAll([
            Permission.bluetooth,
            Permission.location,
          ]);
          AppLogger.info('Using legacy Android Bluetooth permissions');
        }
      } else if (Platform.isIOS) {
        // iOS BLE flow only needs Bluetooth authorization.
        permissionsToRequest.add(Permission.bluetooth);
        AppLogger.info('Using iOS Bluetooth permissions');
      } else {
        AppLogger.info('No runtime Bluetooth permissions required on this platform');
        return true;
      }

      AppLogger.info(
          'Requesting permissions: ${permissionsToRequest.map((p) => p.toString()).join(', ')}');

      final permissions = await permissionsToRequest.request();

      final deniedPermissions = <String>[];
      final permanentlyDenied = <String>[];

      for (final entry in permissions.entries) {
        AppLogger.info('Permission ${entry.key}: ${entry.value}');
        if (!entry.value.isGranted) {
          deniedPermissions.add(entry.key.toString());
        }
        if (entry.value.isPermanentlyDenied) {
          permanentlyDenied.add(entry.key.toString());
        }
      }

      final allGranted = deniedPermissions.isEmpty;

      if (allGranted) {
        AppLogger.info('All Bluetooth permissions granted');
      } else {
        AppLogger.warning('Denied permissions: ${deniedPermissions.join(', ')}');
        if (permanentlyDenied.isNotEmpty) {
          AppLogger.warning(
              'Permanently denied permissions: ${permanentlyDenied.join(', ')}');
        }
      }

      return allGranted;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to request permissions', error, stackTrace);
      return false;
    }
  }

  /// Start scanning for heart rate monitors
  Future<void> startScanning() async {
    try {
      if (_isScanning) {
        AppLogger.info('Already scanning for devices');
        return;
      }

      // Request permissions first
      if (!await requestPermissions()) {
        throw Exception('Bluetooth permissions not granted');
      }

      // Check if Bluetooth is on
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        throw Exception('Bluetooth is not enabled');
      }

      _isScanning = true;
      _addDebugLog('🔍 Starting scan for heart rate monitors');
      _addDebugLog(
          '📱 Note: If device was connected to another app, it may not appear until that connection is closed');

      // Clear previous devices
      _devicesController.add([]);

      // Also check for already connected devices
      List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;
      if (connectedDevices.isNotEmpty) {
        _addDebugLog(
            '🔗 Found ${connectedDevices.length} already connected devices:');
        for (var device in connectedDevices) {
          _addDebugLog(
              '   📱 Connected: ${device.platformName} (${device.remoteId})');
        }
      }

      // Start scanning WITHOUT service filter to catch all devices
      // Many heart rate monitors don't advertise the standard HR service
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15), // Standard timeout
      );

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        _addDebugLog('📡 Scan found ${results.length} total devices');

        // Log all discovered devices for debugging
        for (var result in results) {
          String deviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Unknown Device';
          String deviceId = result.device.remoteId.toString();
          List<String> serviceUuids = result.advertisementData.serviceUuids
              .map((uuid) => uuid.toString())
              .toList();

          _addDebugLog('📱 Found device: "$deviceName" (ID: $deviceId)');
          _addDebugLog('📶 RSSI: ${result.rssi} dBm');
          _addDebugLog(
              '🔧 Services: ${serviceUuids.isEmpty ? "None advertised" : serviceUuids.join(", ")}');
          _addDebugLog(
              '🔗 Connectable: ${result.advertisementData.connectable}');

          // Check if device name contains heart rate monitor keywords
          String nameLower = deviceName.toLowerCase();
          bool isHeartRateDevice = nameLower.contains('magene') ||
              nameLower.contains('h003') ||
              nameLower.contains('h64') ||
              nameLower.contains('polar') ||
              nameLower.contains('garmin') ||
              nameLower.contains('heart') ||
              nameLower.contains('hrm') ||
              nameLower.contains('hr') ||
              nameLower.contains('25055') ||
              serviceUuids.any((uuid) => uuid.toLowerCase().contains('180d'));

          if (isHeartRateDevice) {
            _addDebugLog('❤️ *** POTENTIAL HEART RATE MONITOR DETECTED ***');
          }
        }

        // Filter for heart rate devices
        List<BluetoothDevice> heartRateDevices = results
            .where((result) {
              String name = result.device.platformName.toLowerCase();
              List<String> serviceUuids = result.advertisementData.serviceUuids
                  .map((uuid) => uuid.toString().toLowerCase())
                  .toList();

              // Check by device name
              bool nameMatch = name.contains('magene') ||
                  name.contains('h003') ||
                  name.contains('h64') ||
                  name.contains('polar') ||
                  name.contains('garmin') ||
                  name.contains('heart') ||
                  name.contains('hrm') ||
                  name.contains('hr') ||
                  name.contains('chest') ||
                  name.contains('monitor') ||
                  name.contains('25055');

              // Check by service UUID (heart rate service)
              bool serviceMatch = serviceUuids.any((uuid) =>
                      uuid.contains('180d') || // Heart Rate Service
                      uuid.contains('2a37') // Heart Rate Measurement
                  );

              return nameMatch || serviceMatch;
            })
            .map((result) => result.device)
            .toList();

        if (heartRateDevices.isNotEmpty) {
          _addDebugLog(
              '✅ Found ${heartRateDevices.length} potential heart rate devices:');
          for (var device in heartRateDevices) {
            _addDebugLog(
                '❤️ ${device.platformName.isNotEmpty ? device.platformName : "Unknown"} (${device.remoteId})');
          }
          _devicesController.add(heartRateDevices);
        } else {
          _addDebugLog('❌ No heart rate devices found in this scan cycle');
        }
      });

      // Auto-stop scanning after timeout
      Timer(const Duration(seconds: 10), () {
        if (_isScanning) {
          stopScanning();
        }
      });
    } catch (error, stackTrace) {
      _isScanning = false;
      AppLogger.error('Failed to start scanning', error, stackTrace);
      rethrow;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    try {
      if (!_isScanning) return;

      _isScanning = false;
      await FlutterBluePlus.stopScan();
      AppLogger.info('Stopped scanning for heart rate monitors');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to stop scanning', error, stackTrace);
    }
  }

  /// Connect to a heart rate monitor
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _addDebugLog('🚀 === CONNECTION ATTEMPT STARTED ===');
      _addDebugLog(
          '🔗 Attempting to connect to ${device.platformName} (${device.remoteId})');
      _addDebugLog(
          '📋 Device details: Name="${device.platformName}", ID=${device.remoteId}');

      // Check device state before connecting
      final deviceState = await device.connectionState.first;
      _addDebugLog('📱 Current device state: $deviceState');

      // Disconnect from current device if connected
      if (_isConnected) {
        _addDebugLog('🔌 Disconnecting from existing device first');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
      }

      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      _addDebugLog('📡 Bluetooth adapter state: $adapterState');

      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth adapter is not on: $adapterState');
      }

      _addDebugLog('⏳ Connecting to device (timeout: 15 seconds)...');
      // Connect to the device with longer timeout
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _addDebugLog('✅ Successfully connected to device');

      // Verify connection state
      final newState = await device.connectionState.first;
      _addDebugLog('🔍 Post-connection state: $newState');

      // Discover services
      _addDebugLog('🔍 Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      _addDebugLog('📋 Discovered ${services.length} services');

      // Log all services for debugging
      for (BluetoothService service in services) {
        _addDebugLog('   🔧 Service: ${service.uuid}');
        // Also log characteristics for each service
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          _addDebugLog('      📝 Characteristic: ${characteristic.uuid}');
        }
      }

      // Find heart rate service
      _addDebugLog(
          '🔍 Looking for HR service. Expected: Full="$heartRateServiceUuid" Short="$heartRateServiceShortUuid"');
      BluetoothService? heartRateService;
      for (BluetoothService service in services) {
        if (_isUuidMatch(service.uuid.toString(), heartRateServiceUuid,
            heartRateServiceShortUuid)) {
          heartRateService = service;
          _addDebugLog('❤️ Found Heart Rate Service: ${service.uuid}');
          break;
        }
      }

      if (heartRateService == null) {
        _addDebugLog(
            '⚠️ Heart rate service not found, checking all characteristics');
        // For devices like Magene H003, try to find heart rate characteristic in any service
        for (BluetoothService service in services) {
          _addDebugLog(
              '   🔍 Checking service ${service.uuid} for HR characteristic');
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            _addDebugLog('      📡 Characteristic: ${characteristic.uuid}');
            if (_isUuidMatch(characteristic.uuid.toString(),
                heartRateMeasurementUuid, heartRateMeasurementShortUuid)) {
              _heartRateCharacteristic = characteristic;
              _addDebugLog('      ❤️ Found HR measurement characteristic!');
              break;
            }
          }
          if (_heartRateCharacteristic != null) break;
        }
      } else {
        _addDebugLog(
            '🔍 Searching for HR measurement characteristic in HR service');
        // Find heart rate measurement characteristic
        for (BluetoothCharacteristic characteristic
            in heartRateService.characteristics) {
          _addDebugLog('   📡 Characteristic: ${characteristic.uuid}');
          if (_isUuidMatch(characteristic.uuid.toString(),
              heartRateMeasurementUuid, heartRateMeasurementShortUuid)) {
            _heartRateCharacteristic = characteristic;
            _addDebugLog('   ❤️ Found HR measurement characteristic!');
            break;
          }
        }
      }

      if (_heartRateCharacteristic == null) {
        _addDebugLog('❌ Heart rate measurement characteristic not found');
        throw Exception('Heart rate measurement characteristic not found');
      }

      _addDebugLog('📡 Setting up heart rate notifications...');
      // Subscribe to heart rate notifications
      await _heartRateCharacteristic!.setNotifyValue(true);
      _heartRateSubscription = _heartRateCharacteristic!.lastValueStream.listen(
        _processHeartRateData,
        onError: (error) {
          _addDebugLog('❌ Heart rate data stream error: $error');
          AppLogger.error('Heart rate data stream error', error);
        },
      );

      _isConnected = true;
      _connectionController.add(true);

      _addDebugLog('🎉 Successfully connected to ${device.platformName}!');
      _addDebugLog('🚀 === CONNECTION ATTEMPT COMPLETED SUCCESSFULLY ===');
      AppLogger.info('Successfully connected to ${device.platformName}');
      return true;
    } catch (error, stackTrace) {
      _addDebugLog('💥 === CONNECTION ATTEMPT FAILED ===');
      _addDebugLog('❌ Connection failed: $error');
      _addDebugLog('📊 Error type: ${error.runtimeType}');

      // Provide specific error guidance
      if (error.toString().contains('timeout')) {
        _addDebugLog(
            '⏰ Connection timed out - device may be out of range or busy');
      } else if (error.toString().contains('permission')) {
        _addDebugLog('🔒 Permission error - check Bluetooth permissions');
      } else if (error.toString().contains('adapter')) {
        _addDebugLog(
            '📡 Bluetooth adapter issue - ensure Bluetooth is enabled');
      }

      AppLogger.error('Failed to connect to device', error, stackTrace);
      await disconnect();
      return false;
    }
  }

  /// Process incoming heart rate data
  void _processHeartRateData(List<int> data) {
    try {
      if (data.isEmpty) return;

      // Parse heart rate measurement according to Bluetooth specification
      int heartRate;
      if (data[0] & 0x01 == 0) {
        // Heart rate format is UINT8
        heartRate = data[1];
      } else {
        // Heart rate format is UINT16
        heartRate = (data[2] << 8) | data[1];
      }

      // Validate heart rate (reasonable range: 30-220 BPM)
      if (heartRate >= 30 && heartRate <= 220) {
        _currentHeartRate = heartRate;

        // Add reading with timestamp
        _readings.add(HeartRateReading(
          heartRate: heartRate,
          timestamp: DateTime.now(),
        ));

        // Keep only last 15 minutes of data (900 readings at 1 per second)
        if (_readings.length > 900) {
          _readings.removeAt(0);
        }

        // Emit heart rate update
        _heartRateController.add(heartRate);

        AppLogger.debug('Heart rate: $heartRate BPM');
      } else {
        AppLogger.warning('Invalid heart rate reading: $heartRate BPM');
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to process heart rate data', error, stackTrace);
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      AppLogger.info('Disconnecting from heart rate monitor');

      // Cancel heart rate subscription
      await _heartRateSubscription?.cancel();
      _heartRateSubscription = null;

      // Disconnect from device
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      _heartRateCharacteristic = null;
      _isConnected = false;
      _currentHeartRate = 0;

      _connectionController.add(false);

      AppLogger.info('Disconnected from heart rate monitor');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to disconnect from device', error, stackTrace);
    }
  }

  /// Get heart rate statistics for current session
  HeartRateStats getSessionStats() {
    if (_readings.isEmpty) {
      return HeartRateStats(
        maxHeartRate: 0,
        minHeartRate: 0,
        avgHeartRate: 0,
        currentHeartRate: _currentHeartRate,
        readingsCount: 0,
      );
    }

    List<int> heartRates = _readings.map((r) => r.heartRate).toList();

    return HeartRateStats(
      maxHeartRate: heartRates.reduce((a, b) => a > b ? a : b),
      minHeartRate: heartRates.reduce((a, b) => a < b ? a : b),
      avgHeartRate:
          (heartRates.reduce((a, b) => a + b) / heartRates.length).round(),
      currentHeartRate: _currentHeartRate,
      readingsCount: _readings.length,
    );
  }

  /// Calculate target heart rate zones based on age
  HeartRateZones calculateHeartRateZones(int age) {
    int maxHeartRate = 220 - age;

    return HeartRateZones(
      restingZone: HeartRateZone(
        name: 'Resting',
        minBpm: 50,
        maxBpm: (maxHeartRate * 0.6).round(),
        color: 'blue',
        description: 'Recovery and rest',
      ),
      fatBurnZone: HeartRateZone(
        name: 'Fat Burn',
        minBpm: (maxHeartRate * 0.6).round(),
        maxBpm: (maxHeartRate * 0.7).round(),
        color: 'green',
        description: 'Light activity, fat burning',
      ),
      cardioZone: HeartRateZone(
        name: 'Cardio',
        minBpm: (maxHeartRate * 0.7).round(),
        maxBpm: (maxHeartRate * 0.85).round(),
        color: 'orange',
        description: 'Moderate to vigorous activity',
      ),
      peakZone: HeartRateZone(
        name: 'Peak',
        minBpm: (maxHeartRate * 0.85).round(),
        maxBpm: (maxHeartRate * 0.95).round(),
        color: 'red',
        description: 'High intensity training',
      ),
      vo2MaxZone: HeartRateZone(
        name: 'VO2 Max',
        minBpm: (maxHeartRate * 0.95).round(),
        maxBpm: maxHeartRate,
        color: 'purple',
        description: 'Maximum effort, VO2 max training',
      ),
    );
  }

  /// Get current heart rate zone
  String getCurrentZone(int age) {
    HeartRateZones zones = calculateHeartRateZones(age);

    if (_currentHeartRate <= zones.restingZone.maxBpm) {
      return zones.restingZone.name;
    }
    if (_currentHeartRate <= zones.fatBurnZone.maxBpm) {
      return zones.fatBurnZone.name;
    }
    if (_currentHeartRate <= zones.cardioZone.maxBpm) {
      return zones.cardioZone.name;
    }
    if (_currentHeartRate <= zones.peakZone.maxBpm) return zones.peakZone.name;
    return zones.vo2MaxZone.name;
  }

  /// Dispose of resources
  void dispose() {
    _heartRateSubscription?.cancel();
    _heartRateController.close();
    _connectionController.close();
    _devicesController.close();
    disconnect();
  }
}

/// Heart rate reading with timestamp
class HeartRateReading {
  final int heartRate;
  final DateTime timestamp;

  HeartRateReading({
    required this.heartRate,
    required this.timestamp,
  });
}

/// 15-second heart rate snapshot for VO2 max modeling
class HeartRateSnapshot {
  final DateTime timestamp;
  final int avgHeartRate;
  final int maxHeartRate;
  final int minHeartRate;
  final int readingsCount;

  HeartRateSnapshot({
    required this.timestamp,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.readingsCount,
  });
}

/// Heart rate statistics
class HeartRateStats {
  final int maxHeartRate;
  final int minHeartRate;
  final int avgHeartRate;
  final int currentHeartRate;
  final int readingsCount;

  HeartRateStats({
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.avgHeartRate,
    required this.currentHeartRate,
    required this.readingsCount,
  });
}

/// Heart rate zone definition
class HeartRateZone {
  final String name;
  final int minBpm;
  final int maxBpm;
  final String color;
  final String description;

  HeartRateZone({
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.description,
  });
}

/// Complete heart rate zones
class HeartRateZones {
  final HeartRateZone restingZone;
  final HeartRateZone fatBurnZone;
  final HeartRateZone cardioZone;
  final HeartRateZone peakZone;
  final HeartRateZone vo2MaxZone;

  HeartRateZones({
    required this.restingZone,
    required this.fatBurnZone,
    required this.cardioZone,
    required this.peakZone,
    required this.vo2MaxZone,
  });
}
