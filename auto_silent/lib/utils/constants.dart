import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color accent = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  
  // Prayer time specific colors
  static const Color fajrColor = Color(0xFF303F9F);
  static const Color dhuhrColor = Color(0xFFFF8C00); // Changed to avoid duplicate with accent
  static const Color asrColor = Color(0xFFFFC107);
  static const Color maghribColor = Color(0xFFFF5722);
  static const Color ishaColor = Color(0xFF9C27B0);
  
  // Additional UI colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFFBDBDBD);
}

class AppConstants {
  static const String appName = 'Salah Silence';
  static const String version = '1.0.0';
  static const String packageName = 'com.example.auto_silent';
  
  // Splash screen delays (keeping both as requested)
  static const Duration splashScreenDelay1 = Duration(seconds: 3);
  static const Duration splashScreenDelay = Duration(seconds: 1);
  
  // Prayer names
  static const List<String> prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // Silence duration options
  static const int defaultSilenceDuration = 20;
  static const int minSilenceDuration = 5;
  static const int maxSilenceDuration = 120;
  static const List<int> silenceDurationOptions = [5, 10, 15, 20, 25, 30, 45, 60];

  // Background service settings
  static const String backgroundServiceChannelId = 'salah_background_service';
  static const String backgroundServiceChannelName = 'Salah Background Service';
  static const int backgroundServiceNotificationId = 888;

  // Notification channels (consistent naming with Id suffix)
  static const String silenceModeChannelId = 'salah_silence';
  static const String silenceModeChannelName = 'Salah Silence Mode';
  
  static const String prayerTimesChannelId = 'prayer_times';
  static const String prayerTimesChannelName = 'Prayer Times';
  
  static const String prayerReminderChannelId = 'prayer_reminder';
  static const String prayerReminderChannelName = 'Prayer Reminders';

  // Platform channels
  static const String silentModeChannel = 'com.example.salah_silence/silent_mode';

  // Calculation methods
  static const Map<String, String> calculationMethods = {
    'MuslimWorldLeague': 'Muslim World League',
    'Egyptian': 'Egyptian General Authority of Survey',
    'Karachi': 'University of Islamic Sciences, Karachi',
    'UmmAlQura': 'Umm Al-Qura University, Makkah',
    'Dubai': 'The Gulf Region',
    'MoonsightingCommittee': 'Moonsighting Committee Worldwide',
    'NorthAmerica': 'Islamic Society of North America',
    'Kuwait': 'Kuwait',
    'Qatar': 'Qatar',
    'Singapore': 'Singapore',
  };

  // Default calculation method
  static const String defaultCalculationMethod = 'MuslimWorldLeague';

  // Madhab options
  static const Map<String, String> madhabOptions = {
    'Hanafi': 'Hanafi (حنفی)',
    'Shafi': 'Shafi\'i (شافعی)',
    'Maliki': 'Maliki (مالکی)',
    'Hanbali': 'Hanbali (حنبلی)',
    'Jafari': 'Jafari (جعفری)',
  };

  // Madhab descriptions
  static const Map<String, String> madhabDescriptions = {
    'Hanafi': 'Asr begins when shadow = object length × 2',
    'Shafi': 'Asr begins when shadow = object length × 1',
    'Maliki': 'Asr begins when shadow = object length × 1',
    'Hanbali': 'Asr begins when shadow = object length × 1',
    'Jafari': 'Shia school - Asr begins when shadow = object length × 1',
  };
  
  // Default madhab
  static const String defaultMadhab = 'Shafi';
  
  // WorkManager settings
  static const Duration workManagerInterval = Duration(minutes: 15);
  static const String workManagerTaskName = 'salah_silence_task';
  static const String workManagerPeriodicTaskName = 'salah_silence_periodic';
}

class AppStrings {
  static const String appEnabled = 'Auto Silence Enabled';
  static const String appDisabled = 'Auto Silence Disabled';
  static const String silenceModeActive = 'Silence Mode Active';
  static const String nextPrayer = 'Next Prayer';
  static const String currentPrayer = 'Current Prayer';
  static const String locationRequired = 'Location access is required to calculate prayer times';
  static const String permissionDenied = 'Permission denied';
  static const String errorLoadingPrayerTimes = 'Error loading prayer times';
  static const String locationUpdated = 'Location updated successfully';
  static const String settingsSaved = 'Settings saved';
  static const String prayerTimeUpdated = 'Prayer times updated';
  static const String madhabChanged = 'Madhab selection changed';
  static const String backgroundServiceStarted = 'Background service started';
  static const String backgroundServiceStopped = 'Background service stopped';
  
  // Error messages
  static const String locationError = 'Unable to get location';
  static const String permissionError = 'Permissions not granted';
  static const String calculationError = 'Error calculating prayer times';
  static const String networkError = 'Network connection error';
  
  // Success messages
  static const String dataCleared = 'All data cleared successfully';
  static const String preferencesUpdated = 'Preferences updated';
  static const String permissionGranted = 'Permission granted successfully';
  
  // Button texts
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String retry = 'Retry';
  static const String enable = 'Enable';
  static const String disable = 'Disable';
  static const String grantPermission = 'Grant Permission';
}

class AppDurations {
  static const Duration backgroundCheckInterval = Duration(minutes: 1);
  static const Duration silenceModeDuration = Duration(minutes: 20);
  static const Duration notificationTimeout = Duration(seconds: 5);
  static const Duration locationTimeout = Duration(seconds: 15);
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration retryDelay = Duration(seconds: 1);
  static const Duration animationDuration = Duration(milliseconds: 100);
}

// Prayer time related constants
class PrayerConstants {
  static const Map<String, IconData> prayerIcons = {
    'Fajr': Icons.wb_twilight,
    'Dhuhr': Icons.wb_sunny,
    'Asr': Icons.wb_sunny_outlined,
    'Maghrib': Icons.wb_twilight_outlined,
    'Isha': Icons.nightlight_round,
  };

  static const Map<String, Color> prayerColors = {
    'Fajr': AppColors.fajrColor,
    'Dhuhr': AppColors.dhuhrColor,
    'Asr': AppColors.asrColor,
    'Maghrib': AppColors.maghribColor,
    'Isha': AppColors.ishaColor,
  };
  
  // Prayer emojis for notifications
  static const Map<String, String> prayerEmojis = {
    'Fajr': '🌅',
    'Dhuhr': '☀️',
    'Asr': '🌇',
    'Maghrib': '🌆',
    'Isha': '🌙',
  };
}

// App routes
class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String prayerTimes = '/prayer-times';
  static const String permissions = '/permissions';
  static const String about = '/about';
}

// Storage keys
class StorageKeys {
  static const String userPreferences = 'user_preferences';
  static const String prayerTimes = 'prayer_times';
  static const String location = 'location';
  static const String isFirstLaunch = 'is_first_launch';
  static const String lastUpdateTime = 'last_update_time';
}
