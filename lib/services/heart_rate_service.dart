import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:testfitness/utils/app_logger.dart';

/// High-level state of the heart rate monitor link, for UI display.
enum HeartRateConnectionStatus {
  /// No device connected (never connected, user disconnected, or reconnect
  /// attempts exhausted).
  disconnected,

  /// A user-initiated connection attempt is in progress.
  connecting,

  /// Connected and receiving heart rate notifications.
  connected,

  /// Still connected at the BLE level but no heart rate notification has been
  /// received for [HeartRateService.staleTimeout]. The last BPM is not live.
  stale,

  /// The link dropped unexpectedly and the service is trying to reconnect to
  /// the same device.
  reconnecting,
}

/// Service for managing heart rate monitor connections and data
class HeartRateService {
  static final HeartRateService _instance = HeartRateService._internal();
  factory HeartRateService() => _instance;
  HeartRateService._internal();

  /// No HR notification for this long => reading is considered stale.
  static const Duration staleTimeout = Duration(seconds: 10);

  /// Bounded auto-reconnect after an unexpected disconnect.
  static const int maxReconnectAttempts = 3;

  // Bluetooth state
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _heartRateSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  Timer? _scanTimeoutTimer;
  Timer? _staleTimer;

  /// Incremented whenever a connection is torn down on purpose, so that an
  /// in-flight auto-reconnect loop knows to abort.
  int _connectionGeneration = 0;
  bool _isReconnecting = false;

  // Heart rate data
  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  final StreamController<int?> _liveHeartRateController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<List<BluetoothDevice>> _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<HeartRateConnectionStatus> _statusController =
      StreamController<HeartRateConnectionStatus>.broadcast();
  final ValueNotifier<HeartRateConnectionStatus> _statusNotifier =
      ValueNotifier<HeartRateConnectionStatus>(
          HeartRateConnectionStatus.disconnected);

  // Data tracking
  final List<HeartRateReading> _readings = [];
  int _currentHeartRate = 0;
  DateTime? _lastHeartRateAt;
  DateTime? _connectedAt;
  bool _isConnected = false;
  bool _isScanning = false;

  // Debug logging (debug builds only)
  final List<String> _debugLogs = [];
  final StreamController<List<String>> _debugController =
      StreamController<List<String>>.broadcast();
  final Set<String> _loggedScanDeviceIds = {};
  int _lastLoggedScanCount = -1;
  int _lastLoggedHrDeviceCount = -1;

  // Heart Rate Service UUID (standard Bluetooth SIG)
  static const String heartRateServiceUuid =
      "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementUuid =
      "00002a37-0000-1000-8000-00805f9b34fb";

  // Short UUID versions for comparison
  static const String heartRateServiceShortUuid = "180d";
  static const String heartRateMeasurementShortUuid = "2a37";

  // Streams
  /// Every valid BPM notification (unchanged legacy API; never emits null).
  Stream<int> get heartRateStream => _heartRateController.stream;

  /// Like [heartRateStream] but emits `null` when the reading becomes stale or
  /// the device disconnects, so UIs can blank the number instead of showing an
  /// old value as live.
  Stream<int?> get liveHeartRateStream => _liveHeartRateController.stream;

  /// `true` when connected, `false` on any disconnect (including unexpected
  /// drops; a successful auto-reconnect emits `true` again).
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;
  Stream<List<String>> get debugStream => _debugController.stream;

  /// Detailed link status (connected / stale / reconnecting / ...).
  Stream<HeartRateConnectionStatus> get connectionStatusStream =>
      _statusController.stream;

  /// Same as [connectionStatusStream] but synchronously readable; usable with
  /// `ValueListenableBuilder`.
  ValueListenable<HeartRateConnectionStatus> get connectionStatus =>
      _statusNotifier;

  // Getters
  int get currentHeartRate => _currentHeartRate;

  /// Current BPM, or `null` if not connected or the reading is stale.
  int? get liveHeartRate =>
      _statusNotifier.value == HeartRateConnectionStatus.connected &&
              _lastHeartRateAt != null
          ? _currentHeartRate
          : null;
  bool get isHeartRateStale =>
      _statusNotifier.value == HeartRateConnectionStatus.stale;
  DateTime? get lastHeartRateAt => _lastHeartRateAt;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  bool get isScanning => _isScanning;
  String get connectedDeviceName => _connectedDevice?.platformName ?? '';
  List<HeartRateReading> get readings => List.unmodifiable(_readings);
  List<String> get debugLogs => List.unmodifiable(_debugLogs);

  void _setStatus(HeartRateConnectionStatus status) {
    if (_statusNotifier.value == status) return;
    _statusNotifier.value = status;
    if (!_statusController.isClosed) _statusController.add(status);
    _addDebugLog('Status: ${status.name}');
  }

  void _emitConnection(bool connected) {
    if (!_connectionController.isClosed) _connectionController.add(connected);
  }

  void _emitLive(int? bpm) {
    if (!_liveHeartRateController.isClosed) _liveHeartRateController.add(bpm);
  }

  /// Add debug log entry. No-op in release builds.
  void _addDebugLog(String message) {
    if (!kDebugMode) return;
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logEntry = '[$timestamp] $message';
    _debugLogs.add(logEntry);

    // Keep only last 50 log entries
    if (_debugLogs.length > 50) {
      _debugLogs.removeAt(0);
    }

    if (!_debugController.isClosed) {
      _debugController.add(List.from(_debugLogs));
    }
    AppLogger.debug('[HR] $message');
  }

  /// Clear debug logs
  void clearDebugLogs() {
    _debugLogs.clear();
    if (!_debugController.isClosed) _debugController.add([]);
  }

  /// Helper method to compare UUIDs (handles both short and full formats)
  bool _isUuidMatch(
      String deviceUuid, String targetFullUuid, String targetShortUuid) {
    String deviceUuidLower = deviceUuid.toLowerCase();
    return deviceUuidLower == targetFullUuid.toLowerCase() ||
        deviceUuidLower == targetShortUuid.toLowerCase();
  }

  /// Initialize the heart rate service. Safe to call repeatedly (each screen
  /// calls it); the adapter-state listener is only kept once.
  Future<void> initialize() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        AppLogger.error('Bluetooth not supported on this device');
        return;
      }

      if (_adapterStateSubscription != null) return;

      AppLogger.info('Initializing Heart Rate Service');
      _adapterStateSubscription =
          FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        _addDebugLog('Bluetooth adapter state: $state');
        if (state != BluetoothAdapterState.on &&
            (_isConnected || _isReconnecting)) {
          // Bluetooth turned off: reconnecting cannot succeed.
          disconnect();
        }
      });
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to initialize Heart Rate Service', error, stackTrace);
    }
  }

  /// Waits for the adapter to leave the transient `unknown`/`turningOn`
  /// states. On iOS the first FlutterBluePlus call creates the
  /// CBCentralManager, which is what shows the system Bluetooth prompt; the
  /// state then becomes `on`, `off` or `unauthorized`.
  Future<BluetoothAdapterState> _settledAdapterState() async {
    try {
      return await FlutterBluePlus.adapterState
          .where((s) =>
              s != BluetoothAdapterState.unknown &&
              s != BluetoothAdapterState.turningOn)
          .first
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return FlutterBluePlus.adapterStateNow;
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
        // On iOS, CoreBluetooth itself shows the system prompt (driven by
        // NSBluetoothAlwaysUsageDescription) when FlutterBluePlus creates its
        // CBCentralManager. Authorization is then reported through
        // adapterState (== unauthorized when denied). This does not depend on
        // permission_handler's PERMISSION_BLUETOOTH Podfile macro, which if
        // missing makes Permission.bluetooth always report permanentlyDenied.
        final state = await _settledAdapterState();
        AppLogger.info('iOS Bluetooth adapter state after prompt: $state');
        return state != BluetoothAdapterState.unauthorized;
      } else {
        AppLogger.info(
            'No runtime Bluetooth permissions required on this platform');
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
        AppLogger.warning(
            'Denied permissions: ${deniedPermissions.join(', ')}');
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

  static bool _looksLikeHeartRateMonitor(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final serviceUuids = result.advertisementData.serviceUuids
        .map((uuid) => uuid.toString().toLowerCase())
        .toList();

    final nameMatch = name.contains('magene') ||
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

    final serviceMatch = serviceUuids.any((uuid) =>
        uuid.contains('180d') || // Heart Rate Service
        uuid.contains('2a37')); // Heart Rate Measurement

    return nameMatch || serviceMatch;
  }

  void _onScanResults(List<ScanResult> results) {
    if (results.length != _lastLoggedScanCount) {
      _lastLoggedScanCount = results.length;
      _addDebugLog('Scan: ${results.length} devices seen');
    }

    // Log each device once per scan instead of on every advertisement.
    for (final result in results) {
      final id = result.device.remoteId.toString();
      if (!_loggedScanDeviceIds.add(id)) continue;
      final name = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : 'Unknown Device';
      final services = result.advertisementData.serviceUuids;
      _addDebugLog('Found "$name" ($id) RSSI ${result.rssi} dBm, '
          'services: ${services.isEmpty ? "none" : services.join(", ")}'
          '${_looksLikeHeartRateMonitor(result) ? " [HR candidate]" : ""}');
    }

    final heartRateDevices = results
        .where(_looksLikeHeartRateMonitor)
        .map((result) => result.device)
        .toList();

    if (heartRateDevices.length != _lastLoggedHrDeviceCount) {
      _lastLoggedHrDeviceCount = heartRateDevices.length;
      _addDebugLog('${heartRateDevices.length} potential HR devices');
    }

    if (heartRateDevices.isNotEmpty && !_devicesController.isClosed) {
      _devicesController.add(heartRateDevices);
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
      if (await _settledAdapterState() != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is not enabled');
      }

      _isScanning = true;
      _loggedScanDeviceIds.clear();
      _lastLoggedScanCount = -1;
      _lastLoggedHrDeviceCount = -1;
      _addDebugLog('Starting scan for heart rate monitors');

      // Clear previous devices
      if (!_devicesController.isClosed) _devicesController.add([]);

      for (final device in FlutterBluePlus.connectedDevices) {
        _addDebugLog(
            'Already connected: ${device.platformName} (${device.remoteId})');
      }

      // Subscribe before starting the scan (cancel any previous listener).
      // onScanResults does not replay results from a previous scan.
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.onScanResults.listen(
        _onScanResults,
        onError: (Object e) => _addDebugLog('Scan error: $e'),
      );

      // Scan WITHOUT service filter: many HR straps don't advertise 0x180D.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // Auto-stop scanning after timeout
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (_isScanning) {
          stopScanning();
        }
      });
    } catch (error, stackTrace) {
      _isScanning = false;
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      AppLogger.error('Failed to start scanning', error, stackTrace);
      rethrow;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
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
      _addDebugLog('Connecting to ${device.platformName} (${device.remoteId})');

      // Disconnect from current device (or abort a pending reconnect)
      if (_isConnected || _isReconnecting || _connectedDevice != null) {
        _addDebugLog('Disconnecting from existing device first');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final adapterState = await _settledAdapterState();
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth adapter is not on: $adapterState');
      }

      _setStatus(HeartRateConnectionStatus.connecting);
      final generation = _connectionGeneration;

      await _establishConnection(device, timeout: const Duration(seconds: 15));

      if (generation != _connectionGeneration) {
        // disconnect() was called while we were connecting.
        throw Exception('Connection cancelled');
      }

      _onConnected(device);
      _addDebugLog('Connected to ${device.platformName}');
      AppLogger.info('Successfully connected to ${device.platformName}');
      return true;
    } catch (error, stackTrace) {
      _addDebugLog('Connection failed (${error.runtimeType}): $error');
      if (error.toString().contains('timeout')) {
        _addDebugLog('Timed out - device may be out of range or busy');
      }
      AppLogger.error('Failed to connect to device', error, stackTrace);
      await disconnect();
      return false;
    }
  }

  /// Connects, discovers the HR measurement characteristic and subscribes to
  /// notifications. Throws on failure.
  Future<void> _establishConnection(BluetoothDevice device,
      {required Duration timeout}) async {
    await device.connect(timeout: timeout);
    _connectedDevice = device;

    final services = await device.discoverServices();
    _addDebugLog('Discovered ${services.length} services');

    BluetoothCharacteristic? hrCharacteristic;

    // Prefer the standard Heart Rate service...
    for (final service in services) {
      if (_isUuidMatch(service.uuid.toString(), heartRateServiceUuid,
          heartRateServiceShortUuid)) {
        for (final c in service.characteristics) {
          if (_isUuidMatch(c.uuid.toString(), heartRateMeasurementUuid,
              heartRateMeasurementShortUuid)) {
            hrCharacteristic = c;
            break;
          }
        }
        break;
      }
    }

    // ...but some straps (e.g. Magene H003) expose 0x2A37 elsewhere.
    if (hrCharacteristic == null) {
      _addDebugLog('HR service not found, checking all characteristics');
      outer:
      for (final service in services) {
        for (final c in service.characteristics) {
          if (_isUuidMatch(c.uuid.toString(), heartRateMeasurementUuid,
              heartRateMeasurementShortUuid)) {
            hrCharacteristic = c;
            break outer;
          }
        }
      }
    }

    if (hrCharacteristic == null) {
      throw Exception('Heart rate measurement characteristic not found');
    }

    await _heartRateSubscription?.cancel();
    await hrCharacteristic.setNotifyValue(true);
    _heartRateSubscription = hrCharacteristic.onValueReceived.listen(
      _processHeartRateData,
      onError: (error) {
        _addDebugLog('Heart rate data stream error: $error');
        AppLogger.error('Heart rate data stream error', error);
      },
    );
  }

  /// Marks the link as up and starts watching for drops / stale data.
  void _onConnected(BluetoothDevice device) {
    _isConnected = true;
    _isReconnecting = false;
    _connectedAt = DateTime.now();
    _lastHeartRateAt = null;
    _emitConnection(true);
    // "connected" is confirmed by the first notification; until then (and if
    // none arrives within staleTimeout) the stale watchdog decides.
    _setStatus(HeartRateConnectionStatus.connected);
    _watchDeviceState(device);
    _startStaleWatchdog();
  }

  void _watchDeviceState(BluetoothDevice device) {
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          _isConnected &&
          identical(device, _connectedDevice)) {
        _handleUnexpectedDisconnect(device);
      }
    });
  }

  void _startStaleWatchdog() {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isConnected) return;
      final reference = _lastHeartRateAt ?? _connectedAt;
      if (reference == null) return;
      final isStale = DateTime.now().difference(reference) > staleTimeout;
      if (isStale &&
          _statusNotifier.value == HeartRateConnectionStatus.connected) {
        _addDebugLog('No HR data for ${staleTimeout.inSeconds}s - stale');
        _setStatus(HeartRateConnectionStatus.stale);
        _emitLive(null);
      }
    });
  }

  Future<void> _handleUnexpectedDisconnect(BluetoothDevice device) async {
    AppLogger.warning(
        'Heart rate monitor disconnected unexpectedly: ${device.platformName}');
    _addDebugLog('Device disconnected unexpectedly');

    // Flip state synchronously so a duplicate event can't re-enter.
    _isConnected = false;
    _isReconnecting = true;
    _staleTimer?.cancel();
    _staleTimer = null;
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    await _heartRateSubscription?.cancel();
    _heartRateSubscription = null;

    _emitConnection(false);
    _emitLive(null);
    _setStatus(HeartRateConnectionStatus.reconnecting);

    final generation = _connectionGeneration;
    for (var attempt = 1; attempt <= maxReconnectAttempts; attempt++) {
      // Backoff: 2s, 4s, 8s
      await Future.delayed(Duration(seconds: 1 << attempt));
      if (generation != _connectionGeneration) return; // user disconnected

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _addDebugLog('Bluetooth off - aborting reconnect');
        break;
      }

      _addDebugLog('Reconnect attempt $attempt/$maxReconnectAttempts');
      try {
        await _establishConnection(device,
            timeout: const Duration(seconds: 10));
        if (generation != _connectionGeneration) return;
        _onConnected(device);
        AppLogger.info('Reconnected to ${device.platformName}');
        return;
      } catch (error) {
        _addDebugLog('Reconnect attempt $attempt failed: $error');
        await _heartRateSubscription?.cancel();
        _heartRateSubscription = null;
        try {
          await device.disconnect();
        } catch (_) {}
      }
    }

    if (generation != _connectionGeneration) return;
    AppLogger.warning('Giving up reconnecting to heart rate monitor');
    await disconnect();
  }

  /// Process incoming heart rate data
  void _processHeartRateData(List<int> data) {
    try {
      if (data.length < 2) return;

      // Parse heart rate measurement according to Bluetooth specification
      int heartRate;
      if (data[0] & 0x01 == 0) {
        // Heart rate format is UINT8
        heartRate = data[1];
      } else {
        if (data.length < 3) return;
        // Heart rate format is UINT16
        heartRate = (data[2] << 8) | data[1];
      }

      // Validate heart rate (reasonable range: 30-220 BPM)
      if (heartRate >= 30 && heartRate <= 220) {
        _currentHeartRate = heartRate;
        _lastHeartRateAt = DateTime.now();

        _readings.add(HeartRateReading(
          heartRate: heartRate,
          timestamp: _lastHeartRateAt!,
        ));

        // Keep only last 15 minutes of data (900 readings at 1 per second)
        if (_readings.length > 900) {
          _readings.removeAt(0);
        }

        if (_isConnected &&
            _statusNotifier.value == HeartRateConnectionStatus.stale) {
          _setStatus(HeartRateConnectionStatus.connected);
        }

        if (!_heartRateController.isClosed) _heartRateController.add(heartRate);
        _emitLive(heartRate);
      } else {
        AppLogger.warning('Invalid heart rate reading: $heartRate BPM');
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to process heart rate data', error, stackTrace);
    }
  }

  /// Disconnect from current device (also aborts any auto-reconnect).
  Future<void> disconnect() async {
    _connectionGeneration++;
    try {
      AppLogger.info('Disconnecting from heart rate monitor');

      _staleTimer?.cancel();
      _staleTimer = null;
      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = null;
      await _heartRateSubscription?.cancel();
      _heartRateSubscription = null;

      final device = _connectedDevice;
      _connectedDevice = null;
      if (device != null) {
        await device.disconnect();
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to disconnect from device', error, stackTrace);
    } finally {
      final wasConnected = _isConnected || _isReconnecting;
      _isConnected = false;
      _isReconnecting = false;
      _currentHeartRate = 0;
      _lastHeartRateAt = null;
      _connectedAt = null;

      _emitConnection(false);
      if (wasConnected) _emitLive(null);
      _setStatus(HeartRateConnectionStatus.disconnected);
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
    _scanTimeoutTimer?.cancel();
    _staleTimer?.cancel();
    _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
    disconnect().whenComplete(() {
      _heartRateController.close();
      _liveHeartRateController.close();
      _connectionController.close();
      _devicesController.close();
      _statusController.close();
      _debugController.close();
    });
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
