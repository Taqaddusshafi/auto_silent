import 'package:flutter/material.dart';
import 'package:salah_silence_app/screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/silent_mode_service.dart';
import 'services/storage_service.dart';
import 'services/foreground_service.dart';
import 'services/native_dnd_service.dart'; // ADD THIS IMPORT
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      // 🔥 CRITICAL: Start NATIVE service first (works when app is killed)
      print('🚀 Starting native DND service that survives app kill...');
      final nativeStarted = await NativeDNDService.startNativeService();
      if (nativeStarted) {
        print('✅ Native DND service started - DND will work even when Flutter app is killed!');
      } else {
        print('❌ Failed to start native DND service');
      }
      
      // Continue with Flutter service for UI updates
      final flutterStarted = await PrayerForegroundService.startMonitoring();
      if (flutterStarted) {
        print('✅ Flutter prayer monitoring started successfully');
      } else {
        print('⚠️ Failed to start Flutter prayer monitoring');
        
        // Fallback to AlarmManager
        final silentModeService = SilentModeService();
        final success = await silentModeService.setupDailyPrayerAlarms();
        print(success ? '✅ Fallback AlarmManager scheduled' : '❌ Fallback failed');
      }
    } else {
      print('ℹ️ Auto-silence disabled, not starting monitoring');
    }
  } catch (e) {
    print('❌ Error initializing prayer monitoring: $e');
  }
  
  runApp(const SalahSilenceApp());
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
