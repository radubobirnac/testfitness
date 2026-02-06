import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:testfitness/screens/vo2_max_training_screen.dart';
import 'package:testfitness/services/heart_rate_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';

/// Heart rate monitoring screen for connecting to external heart rate monitors
class HeartRateMonitorScreen extends StatefulWidget {
  const HeartRateMonitorScreen({super.key});

  @override
  State<HeartRateMonitorScreen> createState() => _HeartRateMonitorScreenState();
}

class _HeartRateMonitorScreenState extends State<HeartRateMonitorScreen>
    with TickerProviderStateMixin {
  // Heart rate service
  final HeartRateService _heartRateService = HeartRateService();

  // Connection state
  bool _isConnected = false;
  bool _isScanning = false;
  String _connectedDeviceName = '';
  List<BluetoothDevice> _availableDevices = [];

  // Heart rate data
  int _currentHeartRate = 0;
  final List<int> _heartRateHistory = [];
  int _maxHeartRate = 0;
  int _minHeartRate = 0;
  int _avgHeartRate = 0;

  // Debug logs
  List<String> _debugLogs = [];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.info('❤️ Heart Rate Monitor Screen: Initializing');
    _initializeAnimations();
    _initializeHeartRateService();
    AppLogger.info('❤️ Heart Rate Monitor Screen: Initialization complete');
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear,
    ));
  }

  void _initializeHeartRateService() {
    // Initialize the heart rate service
    _heartRateService.initialize();

    // Listen to heart rate updates
    _heartRateService.heartRateStream.listen((heartRate) {
      if (mounted) {
        setState(() {
          _currentHeartRate = heartRate;
          _heartRateHistory.add(heartRate);

          // Keep only last 60 readings (1 minute)
          if (_heartRateHistory.length > 60) {
            _heartRateHistory.removeAt(0);
          }

          // Calculate stats
          if (_heartRateHistory.isNotEmpty) {
            _maxHeartRate = _heartRateHistory.reduce((a, b) => a > b ? a : b);
            _minHeartRate = _heartRateHistory.reduce((a, b) => a < b ? a : b);
            _avgHeartRate = (_heartRateHistory.reduce((a, b) => a + b) /
                    _heartRateHistory.length)
                .round();
          }
        });

        // Start pulse animation when receiving real data
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      }
    });

    // Listen to connection status
    _heartRateService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          if (!isConnected) {
            _connectedDeviceName = '';
            _currentHeartRate = 0;
            _heartRateHistory.clear();
            _maxHeartRate = 0;
            _minHeartRate = 0;
            _avgHeartRate = 0;
            _pulseController.stop();
          }
        });
      }
    });

    // Listen to discovered devices
    _heartRateService.devicesStream.listen((devices) {
      if (mounted) {
        AppLogger.info('📱 UI received ${devices.length} devices from service');
        setState(() {
          _availableDevices = devices;
        });

        // Show device selection if devices found and scanning
        if (devices.isNotEmpty && _isScanning) {
          AppLogger.info(
              '🔍 Auto-showing device selection dialog for ${devices.length} devices');
          // Add a small delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isScanning) {
              _showDeviceSelectionDialog();
            }
          });
        }
      }
    });

    // Listen to debug logs
    _heartRateService.debugStream.listen((logs) {
      if (mounted) {
        setState(() {
          _debugLogs = logs;
        });
      }
    });
  }

  @override
  void dispose() {
    AppLogger.info('❤️ Heart Rate Monitor Screen: Disposing');
    _pulseController.dispose();
    _scanController.dispose();
    // DON'T dispose the heart rate service - it's a singleton that should persist across screens
    // _heartRateService.dispose(); // ❌ This was causing disconnections when navigating away
    AppLogger.info('❤️ Heart Rate Monitor Screen: Disposed');
    super.dispose();
  }

  void _startScanning() async {
    setState(() {
      _isScanning = true;
      _availableDevices.clear();
    });

    _scanController.repeat();
    HapticFeedback.lightImpact();

    AppLogger.info('Starting heart rate monitor scan');

    try {
      // Start real Bluetooth scanning
      await _heartRateService.startScanning();

      // Auto-stop scanning after 10 seconds if no devices found
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isScanning && _availableDevices.isEmpty) {
          _stopScanning();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No heart rate monitors found',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Make sure your device is:',
                      style: TextStyle(fontSize: 12)),
                  Text('• Turned on and in pairing mode',
                      style: TextStyle(fontSize: 12)),
                  Text('• Close to your phone (within 3 feet)',
                      style: TextStyle(fontSize: 12)),
                  Text('• Not connected to other apps',
                      style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('Also check permissions:',
                      style: TextStyle(fontSize: 12)),
                  Text('• Enable Location and Nearby devices',
                      style: TextStyle(fontSize: 12)),
                  Text('• Turn on Notifications for this app',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        }
      });
    } catch (error) {
      AppLogger.error('Failed to start scanning', error);
      _stopScanning();

      if (mounted) {
        String errorMessage;
        String actionMessage = '';

        if (error.toString().contains('Bluetooth permissions not granted')) {
          errorMessage = 'Bluetooth permissions required';
          actionMessage =
              'Please grant Bluetooth and Location permissions in Settings';
        } else if (error.toString().contains('Bluetooth is not enabled')) {
          errorMessage = 'Bluetooth is disabled';
          actionMessage = 'Please enable Bluetooth in your device settings';
        } else {
          errorMessage = 'Failed to start scanning: $error';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (actionMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(actionMessage, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: error.toString().contains('permissions')
                ? SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () {
                      // This will open app settings where user can grant permissions
                      // Note: You might want to add the 'app_settings' package for this
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  void _stopScanning() async {
    setState(() {
      _isScanning = false;
    });

    _scanController.stop();
    AppLogger.info('Stopped heart rate monitor scan');

    try {
      await _heartRateService.stopScanning();
    } catch (error) {
      AppLogger.error('Failed to stop scanning', error);
    }
  }

  void _showDeviceSelectionDialog() {
    AppLogger.info(
        '🎯 Showing device selection dialog with ${_availableDevices.length} devices');
    _stopScanning();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Available Heart Rate Monitors'),
          content: _availableDevices.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_searching,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No heart rate monitors found'),
                    SizedBox(height: 8),
                    Text(
                      'Make sure your heart rate monitor is:\n• Turned on\n• In pairing mode\n• Close to your device',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _availableDevices.map((device) {
                    return ListTile(
                      leading:
                          const Icon(Icons.monitor_heart, color: Colors.red),
                      title: Text(device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device'),
                      subtitle: Text('ID: ${device.remoteId}'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _connectToDevice(device);
                      },
                    );
                  }).toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startScanning();
              },
              child: const Text('Scan Again'),
            ),
          ],
        );
      },
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    HapticFeedback.heavyImpact();
    AppLogger.info(
        '🔗 UI: Attempting to connect to heart rate monitor: ${device.platformName} (${device.remoteId})');

    // Show connecting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to heart rate monitor...'),
          ],
        ),
      ),
    );

    try {
      // Attempt real Bluetooth connection
      bool connected = await _heartRateService.connectToDevice(device);

      if (mounted) {
        Navigator.of(context).pop(); // Close connecting dialog

        if (connected) {
          setState(() {
            _connectedDeviceName = device.platformName.isNotEmpty
                ? device.platformName
                : 'Heart Rate Monitor';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to $_connectedDeviceName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to ${device.platformName}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (error) {
      AppLogger.error('Connection failed', error);

      if (mounted) {
        Navigator.of(context).pop(); // Close connecting dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _disconnectDevice() async {
    HapticFeedback.mediumImpact();
    AppLogger.info('Disconnecting from heart rate monitor');

    try {
      await _heartRateService.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Heart rate monitor disconnected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      AppLogger.error('Failed to disconnect', error);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnect failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Debug Information'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                _heartRateService.clearDebugLogs();
              },
              tooltip: 'Clear Logs',
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Connection Status: ${_isConnected ? "✅ Connected" : "❌ Disconnected"}'),
                    Text(
                        'Connected Device: ${_connectedDeviceName.isEmpty ? "None" : _connectedDeviceName}'),
                    Text('Current Heart Rate: $_currentHeartRate BPM'),
                    Text('Available Devices: ${_availableDevices.length}'),
                    Text(
                        'Scanning: ${_isScanning ? "🔍 Active" : "⏹️ Stopped"}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Debug logs section
              const Text('Real-time Debug Logs:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _debugLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'No debug logs yet.\nTap "Scan for Devices" to see logs.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _debugLogs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(
                                _debugLogs[index],
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_debugLogs.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                // Store context before async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Copy all debug logs to clipboard
                String allLogs = _debugLogs.join('\n');
                await Clipboard.setData(ClipboardData(text: allLogs));

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Debug logs copied to clipboard!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Logs'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startScanning();
            },
            child: const Text('Start Scan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Heart Rate Monitor'),
          actions: [
            // Debug button to show logs
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                _showDebugInfo();
              },
              tooltip: 'Debug Info',
            ),
            if (_isConnected)
              IconButton(
                icon: const Icon(Icons.bluetooth_disabled),
                onPressed: _disconnectDevice,
                tooltip: 'Disconnect',
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildConnectionSection(),
              const SizedBox(height: 24),
              if (_isConnected) _buildHeartRateDisplay(),
              if (_isConnected) const SizedBox(height: 24),
              if (_isConnected) _buildStatsSection(),
              const Spacer(),
              _buildInstructionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                size: 48,
                color: _isConnected
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _isConnected
                    ? 'Connected to $_connectedDeviceName'
                    : 'No Device Connected',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!_isConnected && !_isScanning) ...[
                ElevatedButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(Icons.search),
                  label: const Text('SCAN FOR DEVICES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                if (_availableDevices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showDeviceSelectionDialog,
                    icon: const Icon(Icons.bluetooth),
                    label:
                        Text('CONNECT TO DEVICE (${_availableDevices.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ],
              if (_isScanning)
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _scanAnimation.value,
                          strokeWidth: 3,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Scanning for heart rate monitors...'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _stopScanning,
                      child: const Text('STOP SCANNING'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartRateDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Current Heart Rate',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getHeartRateColor().withValues(alpha: 0.1),
                      border: Border.all(
                        color: _getHeartRateColor(),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_currentHeartRate',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getHeartRateColor(),
                                fontSize: 36,
                              ),
                        ),
                        Text(
                          'BPM',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: _getHeartRateColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              _getHeartRateZone(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getHeartRateColor(),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('MAX', _maxHeartRate, Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('AVG', _avgHeartRate, Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('MIN', _minHeartRate, Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            'BPM',
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supported Heart Rate Monitors',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const Text('• Magene H64 (Recommended)'),
            const Text('• Polar H10'),
            const Text('• Garmin HRM-Pro'),
            const Text('• Any Bluetooth Low Energy (BLE) heart rate monitor'),
            const SizedBox(height: 16),
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('1. Put on your heart rate monitor'),
            const Text('2. Ensure it\'s properly positioned'),
            const Text('3. Tap "Scan for Devices" to connect'),
            const Text('4. Select your device from the list'),
            const Text('5. Start your workout and monitor your vitals'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VO2MaxTrainingScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.favorite),
                label: const Text('VO2 Max Training'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHeartRateColor() {
    if (_currentHeartRate < 60) return Colors.blue;
    if (_currentHeartRate < 100) return Colors.green;
    if (_currentHeartRate < 140) return Colors.orange;
    return Colors.red;
  }

  String _getHeartRateZone() {
    if (_currentHeartRate < 60) return 'Resting';
    if (_currentHeartRate < 100) return 'Fat Burn';
    if (_currentHeartRate < 140) return 'Cardio';
    if (_currentHeartRate < 170) return 'Peak';
    return 'Maximum';
  }
}
