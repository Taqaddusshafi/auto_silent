import 'package:salah_silence_app/services/prayer_time_service.dart';
import 'package:salah_silence_app/services/silent_mode_service.dart';
import 'package:salah_silence_app/services/storage_service.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static const String _taskName = "salah_silence_task";
  static const String _periodicTaskName = "salah_silence_periodic";
  static const String _oneTimeTaskName = "salah_silence_onetime";

  // Timer for periodic checks when app is active
  Timer? _periodicTimer;
  bool _isServiceRunning = false;

  /// Initialize service (placeholder for workmanager)
  Future<bool> initialize() async {
    try {
      print('Background service initialized (workmanager disabled)');
      return true;
    } catch (e) {
      print('Failed to initialize background service: $e');
      return false;
    }
  }

  /// Start service with timer-based checking (alternative to workmanager)
  Future<bool> startService() async {
    final initialized = await initialize();
    if (!initialized) {
      print('Cannot start service - initialization failed');
      return false;
    }
    
    return await startPeriodicTask();
  }

  /// Start periodic checking using Timer (while app is active)
  Future<bool> startPeriodicTask() async {
    try {
      // Stop existing timer
      await stopPeriodicTask();
      
      _isServiceRunning = true;
      
      // Use Timer for periodic checks (only works when app is in foreground/background)
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 1), // Check every minute for more accuracy
        (timer) async {
          await _performPrayerCheck();
        }
      );
      
      // Perform immediate check
      await _performPrayerCheck();
      
      print('Timer-based prayer checking started (1-minute interval)');
      return true;
    } catch (e) {
      print('Failed to start periodic task: $e');
      return false;
    }
  }

  /// Perform the actual prayer time check and silent mode management
  Future<void> _performPrayerCheck() async {
    if (!_isServiceRunning) return;
    
    try {
      print('=== Prayer Time Check ===');
      print('Timestamp: ${DateTime.now().toIso8601String()}');
      
      // Initialize services
      final silentService = SilentModeService();
      final prayerService = PrayerTimeService();
      final storage = StorageService();
      
      // Check if auto-silence is enabled
      final prefs = await storage.getUserPreferences();
      if (!prefs.isAppEnabled) {
        print('Auto-silence disabled in preferences, skipping check');
        return;
      }
      
      // Check if we should be silent now
      final shouldBeSilent = await prayerService.shouldSilenceNow();
      print('Should be silent now: $shouldBeSilent');
      
      if (shouldBeSilent) {
        final currentPrayer = await prayerService.getCurrentPrayerTime();
        if (currentPrayer != null) {
          print('Enabling silent mode for prayer: ${currentPrayer.name}');
          final result = await silentService.enableSilentModeForPrayer(currentPrayer);
          print('Silent mode enabled: $result');
        } else {
          print('Enabling general silent mode');
          final result = await silentService.enableSilentMode();
          print('Silent mode enabled: $result');
        }
      } else if (silentService.isSilenceModeActive) {
        print('Disabling silent mode');
        final result = await silentService.disableSilentMode();
        print('Silent mode disabled: $result');
      } else {
        print('No action needed - not in prayer time and silent mode not active');
      }
      
      print('=== Prayer Check Completed ===');
    } catch (e) {
      print('Prayer check failed: $e');
    }
  }

  /// Schedule immediate check
  Future<bool> scheduleImmediateCheck() async {
    try {
      await _performPrayerCheck();
      print('Immediate prayer check completed');
      return true;
    } catch (e) {
      print('Failed to perform immediate check: $e');
      return false;
    }
  }

  /// Stop periodic task
  Future<bool> stopPeriodicTask() async {
    try {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      _isServiceRunning = false;
      print('Periodic prayer checking stopped');
      return true;
    } catch (e) {
      print('Failed to stop periodic task: $e');
      return false;
    }
  }

  /// Stop all tasks
  Future<bool> stopAllTasks() async {
    return await stopPeriodicTask();
  }

  /// Check if service is running
  bool get isServiceRunning => _isServiceRunning;

  /// Check if background tasks are supported (always true for timer-based approach)
  Future<bool> isBackgroundTaskSupported() async {
    return true; // Timer-based approach always works
  }

  /// Cleanup when app is disposed
  void dispose() {
    _periodicTimer?.cancel();
    _isServiceRunning = false;
  }
}

// Placeholder callback dispatcher (not used without workmanager)
@pragma('vm:entry-point')
void callbackDispatcher() {
  // This would be used with workmanager
  // Currently disabled to avoid build issues
  print('Callback dispatcher called (workmanager disabled)');
}

/// Helper class for background task management (workmanager disabled version)
class BackgroundTaskManager {
  static final BackgroundService _backgroundService = BackgroundService();

  /// Initialize and start background service
  static Future<bool> setupBackgroundTasks() async {
    try {
      print('Setting up timer-based prayer checking...');
      
      final started = await _backgroundService.startService();
      if (started) {
        print('Timer-based prayer checking setup completed');
        return true;
      } else {
        print('Failed to start prayer checking service');
        return false;
      }
    } catch (e) {
      print('Error setting up prayer checking: $e');
      return false;
    }
  }

  /// Schedule immediate prayer time check
  static Future<bool> checkPrayerTimesNow() async {
    try {
      return await _backgroundService.scheduleImmediateCheck();
    } catch (e) {
      print('Error performing immediate check: $e');
      return false;
    }
  }

  /// Stop all background tasks
  static Future<bool> stopBackgroundTasks() async {
    try {
      return await _backgroundService.stopAllTasks();
    } catch (e) {
      print('Error stopping background tasks: $e');
      return false;
    }
  }

  /// Restart background tasks
  static Future<bool> restartBackgroundTasks() async {
    try {
      print('Restarting prayer checking...');
      await stopBackgroundTasks();
      await Future.delayed(const Duration(seconds: 1));
      return await setupBackgroundTasks();
    } catch (e) {
      print('Error restarting prayer checking: $e');
      return false;
    }
  }

  /// Get service status
  static bool get isRunning => _backgroundService.isServiceRunning;
}
