import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/silent_mode_service.dart';
import '../widgets/toggle_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();
  final SilentModeService _silentModeService = SilentModeService();

  UserPreferences _preferences = UserPreferences();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _storageService.getUserPreferences();
    setState(() {
      _preferences = prefs;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences(UserPreferences prefs) async {
    await _storageService.saveUserPreferences(prefs);
    setState(() {
      _preferences = prefs;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildGeneralSettings(),
          const SizedBox(height: 16),
          _buildPrayerSettings(),
          const SizedBox(height: 16),
          _buildLocationSettings(),
          const SizedBox(height: 16),
          _buildNotificationSettings(),
          const SizedBox(height: 16),
          _buildAdvancedSettings(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Auto Silence'),
                ToggleSwitch(
                  value: _preferences.isAppEnabled,
                  onChanged: (value) {
                    _savePreferences(_preferences.copyWith(isAppEnabled: value));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(child: Text('Silence Duration')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _preferences.silenceDuration,
                      isDense: true,
                      items: [5, 10, 15, 20, 25, 30]
                          .map((duration) => DropdownMenuItem(
                                value: duration,
                                child: Text('$duration min'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _savePreferences(_preferences.copyWith(silenceDuration: value));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prayer Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Calculation Method
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calculation Method',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _preferences.calculationMethod,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'MuslimWorldLeague', child: Text('Muslim World League')),
                        DropdownMenuItem(value: 'Egyptian', child: Text('Egyptian')),
                        DropdownMenuItem(value: 'Karachi', child: Text('Karachi')),
                        DropdownMenuItem(value: 'UmmAlQura', child: Text('Umm Al-Qura')),
                        DropdownMenuItem(value: 'Dubai', child: Text('Dubai')),
                        DropdownMenuItem(value: 'MoonsightingCommittee', child: Text('Moonsighting Committee')),
                        DropdownMenuItem(value: 'NorthAmerica', child: Text('North America')),
                        DropdownMenuItem(value: 'Kuwait', child: Text('Kuwait')),
                        DropdownMenuItem(value: 'Qatar', child: Text('Qatar')),
                        DropdownMenuItem(value: 'Singapore', child: Text('Singapore')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _savePreferences(_preferences.copyWith(calculationMethod: value));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Madhab/Maslak Selection - NEW
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Madhab / Maslak (School of Thought)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Affects Asr prayer timing calculation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _preferences.madhab,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Hanafi', 
                          child: Text('Hanafi (حنفی)')
                        ),
                        DropdownMenuItem(
                          value: 'Shafi', 
                          child: Text('Shafi\'i (شافعی)')
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _savePreferences(_preferences.copyWith(madhab: value));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Text(
              'Enable for prayers:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._buildPrayerToggles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPrayerToggles() {
    final prayers = [
      {'key': 'fajr', 'name': 'Fajr', 'icon': Icons.wb_twilight},
      {'key': 'dhuhr', 'name': 'Dhuhr', 'icon': Icons.wb_sunny},
      {'key': 'asr', 'name': 'Asr', 'icon': Icons.sunny},
      {'key': 'maghrib', 'name': 'Maghrib', 'icon': Icons.wb_twilight},
      {'key': 'isha', 'name': 'Isha', 'icon': Icons.nightlight_round},
    ];

    return prayers.map((prayer) {
      final key = prayer['key'] as String;
      final name = prayer['name'] as String;
      final icon = prayer['icon'] as IconData;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ToggleSwitch(
              value: _preferences.enabledPrayers[key] ?? true,
              onChanged: (value) {
                final updatedPrayers = Map<String, bool>.from(_preferences.enabledPrayers);
                updatedPrayers[key] = value;
                _savePreferences(_preferences.copyWith(enabledPrayers: updatedPrayers));
              },
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildLocationSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Latitude: ${_preferences.latitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Longitude: ${_preferences.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Update Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Notifications'),
                ToggleSwitch(
                  value: _preferences.notificationsEnabled,
                  onChanged: (value) {
                    _savePreferences(_preferences.copyWith(notificationsEnabled: value));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vibrate on Silence Start'),
                ToggleSwitch(
                  value: _preferences.vibrateOnSilenceStart,
                  onChanged: (value) {
                    _savePreferences(_preferences.copyWith(vibrateOnSilenceStart: value));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prayer Time Notifications'),
                ToggleSwitch(
                  value: _preferences.showPrayerNotifications,
                  onChanged: (value) {
                    _savePreferences(_preferences.copyWith(showPrayerNotifications: value));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.do_not_disturb,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              title: const Text('Do Not Disturb Permission'),
              subtitle: const Text('Required for auto-silencing on Android'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _requestDNDPermission,
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
              title: const Text(
                'Clear All Data',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Reset app to default settings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showClearDataDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLocation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );

    final position = await _locationService.getCurrentLocation();
    if (mounted) Navigator.of(context).pop();

    if (position != null) {
      _savePreferences(_preferences.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestDNDPermission() async {
    await _silentModeService.requestDoNotDisturbPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant Do Not Disturb permission in settings'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will reset all settings to default and clear your saved location. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storageService.clearAllData();
              if (mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close settings screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
