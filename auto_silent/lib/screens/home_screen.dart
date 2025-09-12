import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../models/user_preferences.dart';
import '../services/prayer_time_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/background_service.dart';
import '../services/silent_mode_service.dart';
import '../widgets/prayer_time_card.dart';
import '../widgets/toggle_switch.dart';
import '../utils/date_time_utils.dart';
import 'settings_screen.dart';
import 'permissions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PrayerTimeService _prayerService = PrayerTimeService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final BackgroundService _backgroundService = BackgroundService();
  final SilentModeService _silentModeService = SilentModeService();

  List<PrayerTime> _prayerTimes = [];
  UserPreferences _userPreferences = UserPreferences();
  bool _isLoading = true;
  bool _isTestingDND = false;
  String _locationName = 'Unknown Location';
  PrayerTime? _currentPrayer;
  PrayerTime? _nextPrayer;
  Map<String, dynamic> _permissions = {};
  Map<String, dynamic> _deviceInstructions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh permissions and state when app comes to foreground
      _checkPermissionsAndRefresh();
    }
  }

  Future<void> _initializeApp() async {
    await _loadUserPreferences();
    await _checkFirstLaunch();
    await _loadPrayerTimes();
    await _loadPermissions();
    await _loadDeviceInstructions();
    await _startBackgroundService();
    _startPeriodicUpdates();
  }

  Future<void> _checkFirstLaunch() async {
    final isFirstLaunch = await _storageService.isFirstLaunch();
    if (isFirstLaunch && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const PermissionsScreen()),
      );
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await _storageService.getUserPreferences();
    if (mounted) {
      setState(() {
        _userPreferences = prefs;
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await _silentModeService.checkAllPermissions();
      if (mounted) {
        setState(() {
          _permissions = permissions;
        });
      }
    } catch (e) {
      print('Error loading permissions: $e');
    }
  }

  Future<void> _loadDeviceInstructions() async {
    try {
      final instructions = await _silentModeService.getDeviceSpecificInstructions();
      if (mounted) {
        setState(() {
          _deviceInstructions = instructions;
        });
      }
    } catch (e) {
      print('Error loading device instructions: $e');
    }
  }

  Future<void> _checkPermissionsAndRefresh() async {
    await _loadPermissions();
    setState(() {}); // Refresh UI to show updated permission status
  }

  Future<void> _loadPrayerTimes() async {
    try {
      if (_userPreferences.latitude == 0.0 || _userPreferences.longitude == 0.0) {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          await _loadUserPreferences();
        }
      }

      final prayerTimes = await _prayerService.getTodaysPrayerTimes();
      final currentPrayer = await _prayerService.getCurrentPrayerTime();
      final nextPrayer = await _prayerService.getNextPrayerTime();

      final locationName = await _locationService.getCityName(
        _userPreferences.latitude,
        _userPreferences.longitude,
      );

      if (mounted) {
        setState(() {
          _prayerTimes = prayerTimes;
          _currentPrayer = currentPrayer;
          _nextPrayer = nextPrayer;
          _locationName = locationName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading prayer times: $e')),
        );
      }
    }
  }

  Future<void> _startBackgroundService() async {
    await _backgroundService.startService();
  }

  void _startPeriodicUpdates() {
    // Update every minute
    Stream.periodic(const Duration(minutes: 1)).listen((_) {
      if (mounted) {
        _loadPrayerTimes();
        setState(() {}); // Refresh UI for silent mode status
      }
    });
  }

  Future<void> _toggleAppEnabled() async {
    await _storageService.toggleAppEnabled();
    await _loadUserPreferences();
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      await _loadPrayerTimes();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Enhanced DND test functionality
  Future<void> _testDNDFunctionality() async {
    setState(() {
      _isTestingDND = true;
    });

    try {
      // Show testing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.science, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Testing DND'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Testing Do Not Disturb functionality...'),
              const SizedBox(height: 8),
              Text(
                'This will enable silent mode for 30 seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );

      // Check permissions first
      await _loadPermissions();
      
      if (_permissions.isEmpty || _permissions['dnd'] != true) {
        Navigator.of(context).pop(); // Close dialog
        
        await _showPermissionRequiredDialog();
        return;
      }

      // Test enabling silent mode
      final enableResult = await _silentModeService.enableSilentMode();
      
      if (enableResult) {
        Navigator.of(context).pop(); // Close testing dialog
        await _showTestSuccessDialog();
      } else {
        Navigator.of(context).pop(); // Close testing dialog
        await _showTestFailedDialog();
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close testing dialog
      await _showTestErrorDialog(e.toString());
    } finally {
      setState(() {
        _isTestingDND = false;
      });
    }
  }

  Future<void> _showPermissionRequiredDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Permission Required'),
          ],
        ),
        content: const Text(
          'DND permission is not granted. Please grant the permission to test the functionality.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _silentModeService.requestDNDPermissionWithEducation(context);
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTestSuccessDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Test Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.volume_off,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Silent mode is now active!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your device should be silent now. The test will automatically disable silent mode in 30 seconds.',
            ),
            const SizedBox(height: 16),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => 30 - i - 1)
                  .take(30)
                  .where((countdown) => countdown >= 0),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Auto-disable in: ${snapshot.data}s',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _silentModeService.disableSilentMode();
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('Disable Now'),
          ),
        ],
      ),
    );

    // Auto-disable after 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      await _silentModeService.disableSilentMode();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Test completed. Silent mode disabled.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _showTestFailedDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Test Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Failed to enable silent mode. This could be due to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTroubleshootItem('Missing DND permission'),
            _buildTroubleshootItem('Device-specific restrictions'),
            _buildTroubleshootItem('Battery optimization enabled'),
            _buildTroubleshootItem('OEM-specific settings'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For your ${_permissions['manufacturer'] ?? 'device'}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_deviceInstructions['additional_notes'] ?? 'Check device-specific settings'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeviceSetupGuide();
            },
            child: const Text('Setup Guide'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _silentModeService.performComprehensiveDiagnostics();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Diagnostics logged to console'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Run Diagnostics'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTestErrorDialog(String error) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Test Error'),
          ],
        ),
        content: Text('An error occurred during testing:\n\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showDeviceSetupGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Device Setup Guide',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDeviceInfoSection(),
                    const SizedBox(height: 16),
                    _buildSetupStepsSection(),
                    const SizedBox(height: 16),
                    _buildQuickActionsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Device',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Manufacturer: ${_permissions['manufacturer'] ?? 'Unknown'}'),
            Text('Model: ${_permissions['model'] ?? 'Unknown'}'),
            Text('Android Version: ${_permissions['android_version'] ?? 'Unknown'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStepsSection() {
    final steps = _deviceInstructions['steps'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Required Setup Steps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              const Text('No specific setup required for your device.')
            else
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value.toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step)),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _silentModeService.requestDNDPermissionWithEducation(context);
                    },
                    icon: const Icon(Icons.security),
                    label: const Text('DND Permission'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _silentModeService.openAutoStartSettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Device Settings'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _silentModeService.requestIgnoreBatteryOptimizations();
                },
                icon: const Icon(Icons.battery_charging_full),
                label: const Text('Battery Optimization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salah Silence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocation,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _loadUserPreferences();
                _loadPrayerTimes();
                _loadPermissions();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadPrayerTimes();
                await _loadPermissions();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildTestCard(),
                    const SizedBox(height: 16),
                    if (_permissions['dnd'] != true) _buildPermissionWarningCard(),
                    if (_permissions['dnd'] != true) const SizedBox(height: 16),
                    _buildLocationCard(),
                    const SizedBox(height: 16),
                    _buildCurrentPrayerCard(),
                    const SizedBox(height: 16),
                    _buildPrayerTimesList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auto Silence',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ToggleSwitch(
                  value: _userPreferences.isAppEnabled,
                  onChanged: (value) => _toggleAppEnabled(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _userPreferences.isAppEnabled
                  ? 'Device will auto-silence during prayer times'
                  : 'Auto-silence is disabled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _userPreferences.isAppEnabled ? Colors.green : Colors.grey,
              ),
            ),
            if (_silentModeService.isSilenceModeActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_off, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'SILENCE MODE ACTIVE',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Test Functionality',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_silentModeService.isSilenceModeActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_off, 
                          size: 14, 
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Test the Do Not Disturb functionality to ensure it works on your device.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingDND ? null : _testDNDFunctionality,
                    icon: _isTestingDND 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_off),
                    label: Text(_isTestingDND ? 'Testing...' : 'Test Silent Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showDeviceSetupGuide();
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Setup Guide'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_silentModeService.isSilenceModeActive) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.volume_off, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Silent mode is currently active',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _silentModeService.disableSilentMode();
                        setState(() {});
                      },
                      child: const Text('Disable'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionWarningCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Action Required',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Do Not Disturb permission is required for the app to work properly. Please grant the permission.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _silentModeService.requestDNDPermissionWithEducation(context);
                },
                icon: const Icon(Icons.security),
                label: const Text('Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(_locationName),
        subtitle: Text(
          '${_userPreferences.latitude.toStringAsFixed(2)}, ${_userPreferences.longitude.toStringAsFixed(2)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshLocation,
        ),
      ),
    );
  }

  Widget _buildCurrentPrayerCard() {
    if (_currentPrayer != null) {
      final remaining = _silentModeService.remainingSilenceTime;
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.volume_off, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Current Prayer: ${_currentPrayer!.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (remaining != null)
                Text(
                  'Silence ends in: ${DateTimeUtils.formatDuration(remaining)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
      );
    } else if (_nextPrayer != null) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Next Prayer: ${_nextPrayer!.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<Duration>(
                future: _prayerService.getTimeUntilNextPrayer(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      'In: ${DateTimeUtils.formatDuration(snapshot.data!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPrayerTimesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Prayer Times',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _prayerTimes.length,
          itemBuilder: (context, index) {
            final prayer = _prayerTimes[index];
            return PrayerTimeCard(
              prayer: prayer,
              isActive: _currentPrayer?.name == prayer.name,
              isNext: _nextPrayer?.name == prayer.name,
              onToggle: (enabled) async {
                await _storageService.updatePrayerEnabled(prayer.name, enabled);
                await _loadPrayerTimes();
              },
            );
          },
        ),
      ],
    );
  }
}
