import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';

class PrayerForegroundService {
  
  /// Initialize the foreground service
  static Future<void> initializeForegroundService() async {
    // Initialize communication port first (required for latest version)
    FlutterForegroundTask.initCommunicationPort();
    
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'prayer_monitor_channel',
        channelName: 'Prayer Time Monitor',
        channelDescription: 'Monitors prayer times and controls silent mode',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // Every 30 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// FINAL FIX: Start monitoring service - Use alternative approach
  static Future<bool> startMonitoring() async {
    try {
      // Request permissions first
      final NotificationPermission notificationPermission = 
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // FINAL FIX: Check if already running first
      if (await FlutterForegroundTask.isRunningService) {
        // Service already running, just restart it
        await FlutterForegroundTask.restartService();
        return true;
      } else {
        // Start new service
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: '🕌 Prayer Time Monitor',
          notificationText: 'Monitoring prayer times for auto-silence',
          notificationIcon: null, // Use default app icon
          notificationButtons: [
            const NotificationButton(id: 'stop', text: 'Stop'),
          ],
          callback: startPrayerMonitoring,
        );

        // Wait a moment and check if service actually started
        await Future.delayed(Duration(milliseconds: 1000));
        return await FlutterForegroundTask.isRunningService;
      }
    } catch (e) {
      debugPrint('❌ Failed to start foreground service: $e');
      return false;
    }
  }

  /// FINAL FIX: Stop monitoring service - Use alternative approach
  static Future<bool> stopMonitoring() async {
    try {
      // Stop the service
      await FlutterForegroundTask.stopService();

      // Wait a moment and check if service actually stopped
      await Future.delayed(Duration(milliseconds: 500));
      return !(await FlutterForegroundTask.isRunningService);
    } catch (e) {
      debugPrint('❌ Failed to stop foreground service: $e');
      return false;
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}

/// Entry point for background task - MUST be top-level function
@pragma('vm:entry-point')
void startPrayerMonitoring() {
  FlutterForegroundTask.setTaskHandler(PrayerTaskHandler());
}

/// Task handler with correct method signatures
class PrayerTaskHandler extends TaskHandler {
  static const MethodChannel _channel = MethodChannel('com.example.salah_silence/silent_mode');
  
  bool _isInPrayerTime = false;
  String _currentPrayer = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('✅ Prayer monitoring service started (${starter.name})');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Don't use async on void methods - call async method instead
    _checkPrayerTimeAndControlDND(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🛑 Prayer monitoring service stopped (timeout: $isTimeout)');
    
    // Disable DND if active
    if (_isInPrayerTime) {
      await _disableDNDMode();
    }
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('📱 Received data from UI: $data');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    debugPrint('📱 Notification pressed');
  }

  @override
  void onNotificationDismissed() {
    debugPrint('📱 Notification dismissed');
  }

  /// Core prayer time checking logic
  Future<void> _checkPrayerTimeAndControlDND(DateTime now) async {
    try {
      // Get today's prayer times (use your existing logic)
      final prayerTimes = await _getTodaysPrayerTimes();
      
      bool shouldBeInDND = false;
      String activePrayer = '';

      // Check each prayer
      for (final prayer in prayerTimes) {
        final prayerStart = prayer.time;
        final prayerEnd = prayer.time.add(const Duration(minutes: 20)); // Your duration

        if (now.isAfter(prayerStart) && now.isBefore(prayerEnd)) {
          shouldBeInDND = true;
          activePrayer = prayer.name;
          break;
        }
      }

      // Handle DND state changes
      if (shouldBeInDND && !_isInPrayerTime) {
        // Enable DND
        final success = await _enableDNDMode();
        if (success) {
          _isInPrayerTime = true;
          _currentPrayer = activePrayer;
          _updateNotification(
            '🔇 $activePrayer Prayer - Silent',
            'Device silenced for prayer'
          );
          debugPrint('✅ DND enabled for $activePrayer');
        }
      } else if (!shouldBeInDND && _isInPrayerTime) {
        // Disable DND
        final success = await _disableDNDMode();
        if (success) {
          _isInPrayerTime = false;
          final prevPrayer = _currentPrayer;
          _currentPrayer = '';
          _updateNotification(
            '🔊 $prevPrayer Prayer Complete',
            'Sound restored after prayer'
          );
          debugPrint('✅ DND disabled after $prevPrayer');
        }
      } else {
        // Update status
        final nextPrayer = _getNextPrayer(prayerTimes, now);
        _updateNotification(
          '🕌 Prayer Monitor Active',
          nextPrayer != null 
            ? 'Next: ${nextPrayer.name} at ${_formatTime(nextPrayer.time)}'
            : 'Monitoring prayer times...'
        );
      }

      // Send status to UI
      FlutterForegroundTask.sendDataToMain({
        'timestamp': now.toIso8601String(),
        'isInPrayer': _isInPrayerTime,
        'currentPrayer': _currentPrayer,
      });

    } catch (e) {
      debugPrint('❌ Prayer check error: $e');
    }
  }

  /// Enable DND via platform channel
  Future<bool> _enableDNDMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableSilentMode', {
        'duration': 20,
      });
      return result == true;
    } catch (e) {
      debugPrint('❌ Enable DND failed: $e');
      return false;
    }
  }

  /// Disable DND via platform channel
  Future<bool> _disableDNDMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableSilentMode');
      return result == true;
    } catch (e) {
      debugPrint('❌ Disable DND failed: $e');
      return false;
    }
  }

  /// Update notification text
  void _updateNotification(String title, String text) {
    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Get today's prayer times - REPLACE WITH YOUR LOGIC
  Future<List<PrayerTimeModel>> _getTodaysPrayerTimes() async {
    // TODO: Replace this with your actual prayer time calculation
    final now = DateTime.now();
    return [
      PrayerTimeModel(name: 'Fajr', time: DateTime(now.year, now.month, now.day, 5, 30)),
      PrayerTimeModel(name: 'Dhuhr', time: DateTime(now.year, now.month, now.day, 12, 30)),
      PrayerTimeModel(name: 'Asr', time: DateTime(now.year, now.month, now.day, 15, 30)),
      PrayerTimeModel(name: 'Maghrib', time: DateTime(now.year, now.month, now.day, 18, 30)),
      PrayerTimeModel(name: 'Isha', time: DateTime(now.year, now.month, now.day, 20, 30)),
    ];
  }

  /// Get next prayer
  PrayerTimeModel? _getNextPrayer(List<PrayerTimeModel> prayers, DateTime now) {
    for (final prayer in prayers) {
      if (prayer.time.isAfter(now)) {
        return prayer;
      }
    }
    return null;
  }

  /// Format time
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Simple prayer time model to avoid PrayerTime constructor issues
class PrayerTimeModel {
  final String name;
  final DateTime time;

  PrayerTimeModel({
    required this.name,
    required this.time,
  });
}
