import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:salah_silence_app/screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/silent_mode_service.dart';
import 'services/storage_service.dart';
import 'services/foreground_service.dart';
import 'services/native_dnd_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 CRITICAL: Initialize AlarmManager first for app-kill survival
  try {
    await AndroidAlarmManager.initialize();
    print('✅ AlarmManager initialized - alarms will survive app kill');
  } catch (e) {
    print('❌ Failed to initialize AlarmManager: $e');
  }
  
  // Initialize notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.createNotificationChannels();
    print('✅ Notification service initialized');  
  } catch (e) {
    print('❌ Failed to initialize notification service: $e');
  }
  
  // Initialize foreground service
  try {
    await PrayerForegroundService.initializeForegroundService();
    print('✅ Foreground service initialized');
  } catch (e) {
    print('❌ Failed to initialize foreground service: $e');
  }
  
  // Start monitoring if enabled
  try {
    final storageService = StorageService();
    final prefs = await storageService.getUserPreferences();
    
    if (prefs.isAppEnabled) {
      // 🔥 CRITICAL FIRST: Setup AlarmManager for app-kill survival
      print('🚀 Setting up AlarmManager for prayer times - HIGHEST PRIORITY...');
      final silentModeService = SilentModeService();
      final alarmManagerSuccess = await silentModeService.setupDailyPrayerAlarms();
      if (alarmManagerSuccess) {
        print('✅ AlarmManager prayer alarms scheduled - WILL WORK WHEN APP IS KILLED!');
      } else {
        print('❌ CRITICAL: AlarmManager scheduling failed - app-kill protection NOT active');
      }
      
      // 🔥 SECOND: Start NATIVE service (works when app is killed)
      print('🚀 Starting native DND service that survives app kill...');
      final nativeStarted = await NativeDNDService.startNativeService();
      if (nativeStarted) {
        print('✅ Native DND service started - DND will work even when Flutter app is killed!');
      } else {
        print('❌ Failed to start native DND service');
      }
      
      // THIRD: Continue with Flutter service for UI updates (lowest priority)
      final flutterStarted = await PrayerForegroundService.startMonitoring();
      if (flutterStarted) {
        print('✅ Flutter prayer monitoring started successfully');
      } else {
        print('⚠️ Failed to start Flutter prayer monitoring - but AlarmManager should still work');
      }
      
      // Schedule next day's alarms proactively
      _scheduleNextDayAlarms(silentModeService);
      
    } else {
      print('ℹ️ Auto-silence disabled, not starting monitoring');
    }
  } catch (e) {
    print('❌ Error initializing prayer monitoring: $e');
  }
  
  runApp(const SalahSilenceApp());
}

// Helper function to schedule tomorrow's prayers
void _scheduleNextDayAlarms(SilentModeService silentModeService) async {
  try {
    // Schedule for next 3 days to ensure continuous operation
    final multiDaySuccess = await silentModeService.schedulePrayerAlarmsForDays(3);
    if (multiDaySuccess) {
      print('✅ Multi-day AlarmManager scheduling successful - next 3 days covered');
    } else {
      print('⚠️ Multi-day scheduling failed, but today should work');
    }
  } catch (e) {
    print('⚠️ Error scheduling multi-day alarms: $e');
  }
}

class SalahSilenceApp extends StatelessWidget {
  const SalahSilenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
      ),
      home: const SimpleSplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
