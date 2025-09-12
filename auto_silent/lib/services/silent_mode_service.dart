import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/prayer_time.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'prayer_time_service.dart';

class SilentModeService {
  static final SilentModeService _instance = SilentModeService._internal();
  factory SilentModeService() => _instance;
  SilentModeService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.salah_silence/silent_mode');

  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final PrayerTimeService _prayerTimeService = PrayerTimeService();

  bool _isSilenceModeActive = false;
  DateTime? _silenceModeStartTime;
  Timer? _silenceModeTimer;
  bool _isToggling = false;

  // Enhanced permission checking with comprehensive device info
  Future<Map<String, dynamic>> checkAllPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkAllPermissions');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('Error checking permissions: $e');
      
      // Fallback permission checking using Flutter's permission_handler
      return await _getFallbackPermissions();
    }
  }

  Future<Map<String, dynamic>> _getFallbackPermissions() async {
    try {
      final dndStatus = await Permission.accessNotificationPolicy.status;
      
      return {
        'dnd': dndStatus.isGranted,
        'battery_optimization': true, // Assume granted for fallback
        'audio_modification': true,
        'manufacturer': 'unknown',
        'model': 'unknown',
        'android_version': 0,
        'fallback_mode': true,
      };
    } catch (e) {
      print('Fallback permission check failed: $e');
      return {
        'dnd': false,
        'battery_optimization': false,
        'audio_modification': false,
        'error': e.toString(),
      };
    }
  }

  Future<PermissionStatus> checkDNDPermission() async {
    try {
      final hasPermission = await _channel.invokeMethod<bool>('isDNDPermissionGranted');
      return hasPermission == true ? PermissionStatus.granted : PermissionStatus.denied;
    } catch (e) {
      print('Error checking DND permission via native: $e');
      // Fallback to permission_handler
      return await Permission.accessNotificationPolicy.status;
    }
  }

  Future<bool> isDNDPermissionGranted() async {
    try {
      final permissions = await checkAllPermissions();
      return permissions['dnd'] == true;
    } catch (_) {
      return false;
    }
  }

  // NEW METHOD: Request ONLY DND permission (no battery optimization)
  Future<void> requestDNDPermissionOnly(BuildContext context) async {
    // Show educational dialog first
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.volume_off, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Do Not Disturb Permission'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app needs permission to manage Do Not Disturb settings to automatically silence your device during prayer times.\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('You will be redirected to system settings where you need to:\n'),
            const Text('1. Find "Auto Silent" in the list'),
            const Text('2. Toggle the permission ON'),
            const Text('3. Return to this app'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This permission is required for prayer time auto-silence.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      try {
        await _channel.invokeMethod('requestDNDPermissionOnly');
      } catch (e) {
        print('Failed to request DND permission only: $e');
        // Fallback to general DND settings
        await _channel.invokeMethod('openDNDSettings');
      }
    }
  }

  // NEW METHOD: Request ONLY battery optimization exemption
  Future<void> requestBatteryOptimizationOnly(BuildContext context) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.battery_charging_full, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Battery Optimization'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'To ensure the app works in background, please disable battery optimization for this app.\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('This helps the app monitor prayer times even when closed.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This is optional but recommended for better background performance.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disable Optimization'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      try {
        await _channel.invokeMethod('requestBatteryOptimizationOnly');
      } catch (e) {
        print('Failed to request battery optimization only: $e');
        // Fallback to general battery optimization settings
        await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    }
  }

  // Enhanced permission request with user education (UPDATED)
  Future<void> requestDNDPermissionWithEducation(BuildContext context) async {
    // Use the new separate method
    await requestDNDPermissionOnly(context);
  }

  // Standard permission request method (UPDATED - now requests separately)
  Future<void> requestDoNotDisturbPermission() async {
    try {
      final permissions = await checkAllPermissions();
      
      if (permissions['dnd'] != true) {
        try {
          await _channel.invokeMethod('requestDNDPermissionOnly');
        } catch (e) {
          print('Failed to request DND permission only: $e');
          // Fallback to old method
          try {
            await _channel.invokeMethod('openAppSpecificDNDSettings');
          } catch (_) {
            await _channel.invokeMethod('openDNDSettings');
          }
        }
      }
    } catch (e) {
      print('Error requesting DND permission: $e');
    }
  }

  // NEW METHOD: Request battery optimization separately
  Future<void> requestBatteryOptimization() async {
    try {
      final permissions = await checkAllPermissions();
      
      if (permissions['battery_optimization'] != true) {
        try {
          await _channel.invokeMethod('requestBatteryOptimizationOnly');
        } catch (e) {
          print('Failed to request battery optimization only: $e');
          // Fallback to old method
          await requestIgnoreBatteryOptimizations();
        }
      }
    } catch (e) {
      print('Error requesting battery optimization: $e');
    }
  }

  // ===== NEW ALARMMANAGER METHODS =====

  /// NEW: Schedule a single prayer alarm using AlarmManager
  Future<bool> schedulePrayerAlarm(String prayerName, DateTime prayerTime, int durationMinutes) async {
    try {
      final result = await _channel.invokeMethod('schedulePrayerAlarm', {
        'prayer_name': prayerName,
        'start_time_millis': prayerTime.millisecondsSinceEpoch,
        'duration_minutes': durationMinutes,
      });
      
      print('✅ Scheduled AlarmManager alarm for $prayerName at ${prayerTime.toString()}');
      return result == true;
    } catch (e) {
      print('❌ Failed to schedule AlarmManager alarm for $prayerName: $e');
      return false;
    }
  }

  /// NEW: Cancel a specific prayer alarm
  Future<bool> cancelPrayerAlarm(String prayerName) async {
    try {
      final result = await _channel.invokeMethod('cancelPrayerAlarm', {
        'prayer_name': prayerName,
      });
      
      print('✅ Cancelled AlarmManager alarm for $prayerName');
      return result == true;
    } catch (e) {
      print('❌ Failed to cancel AlarmManager alarm for $prayerName: $e');
      return false;
    }
  }

  /// NEW: Schedule all today's prayers at once using AlarmManager
  Future<bool> scheduleAllTodaysPrayers(List<PrayerTime> todaysPrayers, int silenceDuration) async {
    try {
      // Prepare prayer data for native call
      final prayerData = todaysPrayers.map((prayer) => {
        'name': prayer.name,
        'time_millis': prayer.time.millisecondsSinceEpoch,
      }).toList();
      
      // Schedule all prayers at once using native method
      final result = await _channel.invokeMethod('scheduleAllTodaysPrayerAlarms', {
        'prayers': prayerData,
        'duration_minutes': silenceDuration,
      });
      
      print('✅ Scheduled ${todaysPrayers.length} AlarmManager prayer alarms for today');
      return result == true;
    } catch (e) {
      print('❌ Failed to schedule all AlarmManager prayer alarms: $e');
      return false;
    }
  }

  /// NEW: Cancel all scheduled prayer alarms
  Future<bool> cancelAllPrayerAlarms() async {
    try {
      final result = await _channel.invokeMethod('cancelAllPrayerAlarms');
      print('✅ Cancelled all AlarmManager prayer alarms');
      return result == true;
    } catch (e) {
      print('❌ Failed to cancel all AlarmManager alarms: $e');
      return false;
    }
  }

  /// NEW: Enhanced method to setup daily prayer alarms using AlarmManager
  Future<bool> setupDailyPrayerAlarms() async {
    try {
      print('🔄 Setting up daily prayer alarms with AlarmManager...');
      
      final todaysPrayers = await _prayerTimeService.getTodaysPrayerTimes();
      final prefs = await _storageService.getUserPreferences();
      
      if (!prefs.isAppEnabled) {
        print('⚠️ App disabled, not scheduling AlarmManager alarms');
        return false;
      }

      // Check DND permission before scheduling
      final hasPermission = await isDNDPermissionGranted();
      if (!hasPermission) {
        print('⚠️ DND permission not granted, cannot schedule AlarmManager alarms');
        return false;
      }

      // Filter future prayers only (no point scheduling past prayers)
      final now = DateTime.now();
      final futurePrayers = todaysPrayers.where((prayer) => 
        prayer.time.isAfter(now)
      ).toList();

      if (futurePrayers.isEmpty) {
        print('ℹ️ No more prayers today, will need to schedule tomorrow');
        // You might want to schedule tomorrow's prayers here
        return true;
      }

      // Schedule all future prayers for today
      final success = await scheduleAllTodaysPrayers(futurePrayers, prefs.silenceDuration);
      
      if (success) {
        print('✅ Successfully scheduled ${futurePrayers.length} AlarmManager prayer alarms:');
        for (final prayer in futurePrayers) {
          print('   📅 ${prayer.name}: ${prayer.time.toString()}');
        }
      } else {
        print('❌ Failed to schedule AlarmManager prayer alarms');
      }
      
      return success;
    } catch (e) {
      print('❌ Error setting up daily AlarmManager prayer alarms: $e');
      return false;
    }
  }

  /// NEW: Schedule prayer alarms for multiple days (useful for scheduling ahead)
  Future<bool> schedulePrayerAlarmsForDays(int numberOfDays) async {
    try {
      print('🔄 Setting up prayer alarms for next $numberOfDays days...');
      
      final prefs = await _storageService.getUserPreferences();
      
      if (!prefs.isAppEnabled) {
        print('⚠️ App disabled, not scheduling alarms');
        return false;
      }

      // Check DND permission
      final hasPermission = await isDNDPermissionGranted();
      if (!hasPermission) {
        print('⚠️ DND permission not granted');
        return false;
      }

      // Cancel existing alarms first
      await cancelAllPrayerAlarms();

      int totalScheduled = 0;
      final now = DateTime.now();

      for (int day = 0; day < numberOfDays; day++) {
        final targetDate = now.add(Duration(days: day));
        
        try {
          final dayPrayers = await _prayerTimeService.getPrayerTimesForDate(targetDate);
          
          // Filter future prayers for today, or all prayers for future days
          final prayersToSchedule = day == 0 
            ? dayPrayers.where((prayer) => prayer.time.isAfter(now)).toList()
            : dayPrayers;

          // Schedule each prayer individually to ensure proper error handling
          for (final prayer in prayersToSchedule) {
            try {
              final scheduled = await schedulePrayerAlarm(
                prayer.name, 
                prayer.time, 
                prefs.silenceDuration
              );
              if (scheduled) {
                totalScheduled++;
              }
            } catch (e) {
              print('❌ Failed to schedule ${prayer.name} for ${targetDate.toString().substring(0, 10)}: $e');
            }
          }
        } catch (e) {
          print('❌ Failed to get prayer times for ${targetDate.toString().substring(0, 10)}: $e');
        }
      }

      print('✅ Successfully scheduled $totalScheduled prayer alarms across $numberOfDays days');
      return totalScheduled > 0;
    } catch (e) {
      print('❌ Error scheduling multi-day prayer alarms: $e');
      return false;
    }
  }

  /// NEW: Reschedule alarms (useful for settings changes or after reboot)
  Future<bool> rescheduleAlarms() async {
    try {
      print('🔄 Rescheduling all prayer alarms...');
      
      // Cancel all existing alarms first
      await cancelAllPrayerAlarms();
      
      // Wait a moment for cancellation to process
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Setup new alarms
      return await setupDailyPrayerAlarms();
    } catch (e) {
      print('❌ Error rescheduling alarms: $e');
      return false;
    }
  }

  // ===== END NEW ALARMMANAGER METHODS =====

  // Get device-specific setup instructions
  Future<Map<String, dynamic>> getDeviceSpecificInstructions() async {
    final permissions = await checkAllPermissions();
    final manufacturer = permissions['manufacturer']?.toString().toLowerCase() ?? '';
    
    final instructions = <String, dynamic>{
      'manufacturer': permissions['manufacturer'],
      'model': permissions['model'],
      'android_version': permissions['android_version'],
      'steps': <String>[],
      'settings_path': '',
      'additional_notes': '',
    };

    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi') || manufacturer.contains('poco')) {
      instructions['steps'] = [
        'Go to Settings > Apps > Manage apps > ${_getAppName()}',
        'Enable "Autostart"',
        'Go to "Battery saver" and select "No restrictions"',
        'In Recent apps, lock the app by tapping the lock icon',
        'Go to Settings > Additional settings > Privacy > Special app access > Device & app notifications'
      ];
      instructions['settings_path'] = 'Settings > Apps > Manage apps';
      instructions['additional_notes'] = 'MIUI is known for aggressive battery management. All steps are essential.';
    } else if (manufacturer.contains('huawei')) {
      instructions['steps'] = [
        'Go to Settings > Battery > App launch',
        'Find ${_getAppName()} and tap "Manage manually"',
        'Enable: Auto-launch, Secondary launch, and Run in background',
        'Go to Settings > Apps > Special access > Ignore battery optimization',
        'Add ${_getAppName()} to the whitelist'
      ];
      instructions['settings_path'] = 'Settings > Battery > App launch';
      instructions['additional_notes'] = 'Some Huawei devices have PowerGenie that may need to be disabled.';
    } else if (manufacturer.contains('samsung')) {
      instructions['steps'] = [
        'Go to Settings > Device care > Battery',
        'Tap "App power management"',
        'Turn off "Adaptive battery" or add ${_getAppName()} to "Never sleeping apps"',
        'Go to Settings > Apps > ${_getAppName()} > Battery > Optimize battery usage',
        'Select "All apps" and turn off optimization for ${_getAppName()}'
      ];
      instructions['settings_path'] = 'Settings > Device care > Battery';
      instructions['additional_notes'] = 'Samsung One UI may reset DND settings. Create a routine as backup.';
    } else if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
      instructions['steps'] = [
        'Go to Settings > Battery > Battery Optimization',
        'Find ${_getAppName()} and select "Don\'t optimize"',
        'Go to Settings > Privacy permissions > Startup manager',
        'Enable ${_getAppName()}',
        'Go to Settings > Additional settings > Privacy > Device administrators'
      ];
      instructions['settings_path'] = 'Settings > Battery';
      instructions['additional_notes'] = 'ColorOS has multiple battery management layers.';
    } else if (manufacturer.contains('vivo')) {
      instructions['steps'] = [
        'Go to Settings > Battery > Background app refresh',
        'Enable ${_getAppName()}',
        'Go to Settings > More settings > Permission management > Autostart',
        'Enable ${_getAppName()}',
        'Go to Settings > Battery > High background power consumption'
      ];
      instructions['settings_path'] = 'Settings > Battery';
      instructions['additional_notes'] = 'Vivo FunTouch OS requires multiple permission grants.';
    } else {
      instructions['steps'] = [
        'Go to Settings > Battery > Battery optimization',
        'Select "All apps" and find ${_getAppName()}',
        'Select "Don\'t optimize"',
        'Ensure Do Not Disturb permission is granted',
        'Check notification access permissions'
      ];
      instructions['settings_path'] = 'Settings > Battery';
      instructions['additional_notes'] = 'Standard Android settings should be sufficient.';
    }

    return instructions;
  }

  String _getAppName() {
    return 'Auto Silent'; // Updated to match your app name
  }

  // More robust silent mode activation
  Future<bool> enableSilentMode() async {
    if (_isToggling) return _isSilenceModeActive;
    _isToggling = true;
    
    try {
      // Pre-flight checks
      final permissions = await checkAllPermissions();
      print('Permissions status: $permissions');
      
      if (permissions['dnd'] != true) {
        print('DND permission not granted');
        return false;
      }

      final prefs = await _storageService.getUserPreferences();
      
      // Try multiple times for reliability
      bool success = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await _channel.invokeMethod<bool>('enableSilentMode', {
            'duration': prefs.silenceDuration,
          });
          
          if (result == true) {
            success = true;
            break;
          }
          
          // Wait before retry
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        } catch (e) {
          print('Attempt ${attempt + 1} failed: $e');
        }
      }

      if (success) {
        _isSilenceModeActive = true;
        _silenceModeStartTime = DateTime.now();
        _setSilenceModeTimer(prefs.silenceDuration);

        if (prefs.vibrateOnSilenceStart) {
          await _vibrate();
        }

        final currentPrayer = await _prayerTimeService.getCurrentPrayerTime();
        await _notificationService.showSilenceModeNotification(prayer: currentPrayer);
        
        print('Silent mode enabled successfully at ${DateTime.now()}');
      } else {
        print('Failed to enable silent mode after 3 attempts');
      }
      
      return success;
    } catch (e) {
      print('Error in enableSilentMode: $e');
      return false;
    } finally {
      _isToggling = false;
    }
  }

  Future<bool> enableSilentModeForPrayer(PrayerTime prayer) async {
    if (_isToggling) return _isSilenceModeActive;
    _isToggling = true;
    
    try {
      if (_isSilenceModeActive) {
        final prefs = await _storageService.getUserPreferences();
        _setSilenceModeTimer(prefs.silenceDuration);
        print('Silent mode already active, refreshing timer for prayer: ${prayer.name}');
        return true;
      }

      final permissions = await checkAllPermissions();
      if (permissions['dnd'] != true) {
        print('DND permission not granted for prayer: ${prayer.name}');
        return false;
      }

      final prefs = await _storageService.getUserPreferences();
      
      // Multiple attempts for prayer-specific silencing
      bool success = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await _channel.invokeMethod<bool>('enableSilentMode', {
            'duration': prefs.silenceDuration,
          });
          
          if (result == true) {
            success = true;
            break;
          }
          
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        } catch (e) {
          print('Prayer silent mode attempt ${attempt + 1} failed: $e');
        }
      }

      if (success) {
        _isSilenceModeActive = true;
        _silenceModeStartTime = DateTime.now();
        _setSilenceModeTimer(prefs.silenceDuration);

        if (prefs.vibrateOnSilenceStart) {
          await _vibrate();
        }

        await _notificationService.showSilenceModeNotification(prayer: prayer);
        print('Silent mode enabled for prayer: ${prayer.name} at ${DateTime.now()}');
      } else {
        print('Failed to enable silent mode for prayer: ${prayer.name}');
      }
      
      return success;
    } catch (e) {
      print('Error in enableSilentModeForPrayer: $e');
      return false;
    } finally {
      _isToggling = false;
    }
  }

  void _setSilenceModeTimer(int durationMinutes) {
    _silenceModeTimer?.cancel();
    _silenceModeTimer = Timer(Duration(minutes: durationMinutes), () async {
      print('Silent mode timer expired after $durationMinutes minutes, disabling...');
      await disableSilentMode();
    });
  }

  Future<bool> disableSilentMode() async {
    if (_isToggling) return !_isSilenceModeActive;
    _isToggling = true;
    
    try {
      _silenceModeTimer?.cancel();
      
      // Multiple attempts to disable
      bool success = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await _channel.invokeMethod<bool>('disableSilentMode');
          if (result == true) {
            success = true;
            break;
          }
          
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        } catch (e) {
          print('Disable attempt ${attempt + 1} failed: $e');
        }
      }
      
      if (success) {
        _isSilenceModeActive = false;
        _silenceModeStartTime = null;
        await _notificationService.cancelSilenceModeNotification();
        print('Silent mode disabled successfully at ${DateTime.now()}');
      } else {
        print('Failed to disable silent mode after 3 attempts');
      }
      
      return success;
    } catch (e) {
      print('Error in disableSilentMode: $e');
      return false;
    } finally {
      _isToggling = false;
    }
  }

  // Enhanced diagnostics with comprehensive testing
  Future<bool> performComprehensiveDiagnostics() async {
    try {
      print('=== COMPREHENSIVE DND DIAGNOSTICS ===');
      print('Timestamp: ${DateTime.now().toIso8601String()}');
      
      final permissions = await checkAllPermissions();
      print('Permissions: $permissions');
      
      // Test native channel connectivity
      try {
        final testResults = await _channel.invokeMethod<Map>('testDNDFunctionality');
        print('Native Test Results: $testResults');
      } catch (e) {
        print('Native channel test failed: $e');
      }
      
      // Test permission status
      final dndStatus = await checkDNDPermission();
      print('DND Permission Status: $dndStatus');
      
      // Test current state
      print('Current silent mode state:');
      print('  - Active: $_isSilenceModeActive');
      print('  - Start time: $_silenceModeStartTime');
      print('  - Remaining time: ${remainingSilenceTime}');
      
      // Test device info
      print('Device Information:');
      print('  - Manufacturer: ${permissions['manufacturer']}');
      print('  - Model: ${permissions['model']}');
      print('  - Android Version: ${permissions['android_version']}');
      
      // NEW: Test AlarmManager functionality
      print('Testing AlarmManager functionality...');
      try {
        // Test scheduling a prayer alarm 1 minute in the future
        final testTime = DateTime.now().add(const Duration(minutes: 1));
        final alarmScheduled = await schedulePrayerAlarm('Test', testTime, 1);
        print('AlarmManager test scheduling result: $alarmScheduled');
        
        if (alarmScheduled) {
          // Cancel the test alarm immediately
          await Future.delayed(const Duration(milliseconds: 100));
          final alarmCancelled = await cancelPrayerAlarm('Test');
          print('AlarmManager test cancellation result: $alarmCancelled');
        }
      } catch (e) {
        print('AlarmManager test failed: $e');
      }
      
      // Test actual DND functionality if permission is granted
      if (permissions['dnd'] == true) {
        print('Testing DND activation...');
        final enableResult = await enableSilentMode();
        print('Enable result: $enableResult');
        
        if (enableResult) {
          // Wait 2 seconds then disable
          print('Waiting 2 seconds before disabling...');
          await Future.delayed(Duration(seconds: 2));
          final disableResult = await disableSilentMode();
          print('Disable result: $disableResult');
          
          print('=== DIAGNOSTICS COMPLETED - SUCCESS ===');
          return disableResult;
        } else {
          print('=== DIAGNOSTICS COMPLETED - ENABLE FAILED ===');
          return false;
        }
      } else {
        print('=== DIAGNOSTICS COMPLETED - NO PERMISSION ===');
        return false;
      }
      
    } catch (e) {
      print('Diagnostics failed with error: $e');
      print('=== DIAGNOSTICS COMPLETED - ERROR ===');
      return false;
    }
  }

  // Legacy diagnostic method for backward compatibility
  Future<void> performDiagnostics() async {
    await performComprehensiveDiagnostics();
  }

  // Getters
  bool get isSilenceModeActive => _isSilenceModeActive;
  DateTime? get silenceModeStartTime => _silenceModeStartTime;

  Duration? get remainingSilenceTime {
    if (!_isSilenceModeActive || _silenceModeStartTime == null) return null;
    try {
      final prefs = _storageService.getUserPreferencesSync();
      final endTime = _silenceModeStartTime!.add(Duration(minutes: prefs.silenceDuration));
      final remaining = endTime.difference(DateTime.now());
      return remaining.isNegative ? Duration.zero : remaining;
    } catch (_) {
      return null;
    }
  }

  // Utility methods
  Future<void> _vibrate() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Vibration failed: $e');
    }
  }

  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      print('Failed to open auto-start settings: $e');
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      print('Failed to request battery optimization exemption: $e');
    }
  }

  // Test method for quick DND functionality verification
  Future<bool> quickDNDTest() async {
    try {
      print('Starting quick DND test...');
      
      final hasPermission = await isDNDPermissionGranted();
      if (!hasPermission) {
        print('Quick test failed: No DND permission');
        return false;
      }
      
      final enableResult = await enableSilentMode();
      if (!enableResult) {
        print('Quick test failed: Could not enable DND');
        return false;
      }
      
      await Future.delayed(Duration(seconds: 1));
      
      final disableResult = await disableSilentMode();
      if (!disableResult) {
        print('Quick test warning: Could not disable DND');
      }
      
      print('Quick DND test completed successfully');
      return enableResult;
      
    } catch (e) {
      print('Quick DND test error: $e');
      return false;
    }
  }

  // Method to check if device needs special configuration
  Future<bool> requiresSpecialConfiguration() async {
    final permissions = await checkAllPermissions();
    final manufacturer = permissions['manufacturer']?.toString().toLowerCase() ?? '';
    
    return manufacturer.contains('xiaomi') || 
           manufacturer.contains('redmi') || 
           manufacturer.contains('poco') ||
           manufacturer.contains('huawei') ||
           manufacturer.contains('oppo') ||
           manufacturer.contains('vivo');
  }

  // Method to get configuration urgency level
  Future<String> getConfigurationUrgency() async {
    final permissions = await checkAllPermissions();
    final manufacturer = permissions['manufacturer']?.toString().toLowerCase() ?? '';
    
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi') || manufacturer.contains('poco')) {
      return 'CRITICAL'; // MIUI is very aggressive
    } else if (manufacturer.contains('huawei')) {
      return 'HIGH'; // EMUI has PowerGenie
    } else if (manufacturer.contains('oppo') || manufacturer.contains('vivo')) {
      return 'MEDIUM'; // ColorOS/FunTouch OS has some restrictions
    } else if (manufacturer.contains('samsung')) {
      return 'LOW'; // Generally more compliant
    } else {
      return 'MINIMAL'; // Stock Android
    }
  }

  // Cleanup method
  Future<void> cleanup() async {
    _silenceModeTimer?.cancel();
    if (_isSilenceModeActive) {
      await disableSilentMode();
    }
    // NEW: Cancel all scheduled alarms on cleanup
    try {
      await cancelAllPrayerAlarms();
    } catch (e) {
      print('Failed to cancel alarms during cleanup: $e');
    }
  }

  // Reset service state
  void resetState() {
    _silenceModeTimer?.cancel();
    _isSilenceModeActive = false;
    _silenceModeStartTime = null;
    _isToggling = false;
  }
}
