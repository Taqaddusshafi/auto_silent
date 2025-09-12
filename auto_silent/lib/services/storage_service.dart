import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _userPreferencesKey = 'user_preferences';
  static const String _firstLaunchKey = 'first_launch';
  static const String _lastPrayerCheckKey = 'last_prayer_check';

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> get _prefsInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get user preferences with error handling
  Future<UserPreferences> getUserPreferences() async {
    try {
      final prefs = await _prefsInstance;
      final jsonString = prefs.getString(_userPreferencesKey);
      
      if (jsonString == null) {
        final defaultPrefs = UserPreferences();
        await saveUserPreferences(defaultPrefs);
        return defaultPrefs;
      }

      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return UserPreferences.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user preferences: $e');
      }
      // Return default preferences on error
      final defaultPrefs = UserPreferences();
      await saveUserPreferences(defaultPrefs);
      return defaultPrefs;
    }
  }

  /// Synchronous getter - only use if you're sure prefs are initialized
  UserPreferences getUserPreferencesSync() {
    if (_prefs == null) {
      if (kDebugMode) {
        print('Warning: Trying to get preferences synchronously before initialization');
      }
      return UserPreferences();
    }
    
    try {
      final jsonString = _prefs!.getString(_userPreferencesKey);
      if (jsonString == null) return UserPreferences();

      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return UserPreferences.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing user preferences synchronously: $e');
      }
      return UserPreferences();
    }
  }

  /// Save user preferences
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    try {
      final prefs = await _prefsInstance;
      final jsonString = json.encode(preferences.toJson());
      await prefs.setString(_userPreferencesKey, jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving user preferences: $e');
      }
      rethrow;
    }
  }

  /// Check if this is the first app launch
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await _prefsInstance;
      final isFirst = prefs.getBool(_firstLaunchKey) ?? true;
      
      // If it's first launch, mark it as complete
      if (isFirst) {
        await setFirstLaunchComplete();
      }
      
      return isFirst;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking first launch: $e');
      }
      return true; // Default to first launch on error
    }
  }

  /// Mark first launch as complete
  Future<void> setFirstLaunchComplete() async {
    try {
      final prefs = await _prefsInstance;
      await prefs.setBool(_firstLaunchKey, false);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting first launch complete: $e');
      }
    }
  }

  /// Get last prayer check timestamp
  Future<DateTime?> getLastPrayerCheck() async {
    try {
      final prefs = await _prefsInstance;
      final timestamp = prefs.getInt(_lastPrayerCheckKey);
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting last prayer check: $e');
      }
      return null;
    }
  }

  /// Set last prayer check timestamp
  Future<void> setLastPrayerCheck(DateTime dateTime) async {
    try {
      final prefs = await _prefsInstance;
      await prefs.setInt(_lastPrayerCheckKey, dateTime.millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting last prayer check: $e');
      }
    }
  }

  /// Update specific prayer enabled status
  Future<void> updatePrayerEnabled(String prayerName, bool enabled) async {
    try {
      final currentPrefs = await getUserPreferences();
      final updatedEnabledPrayers = Map<String, bool>.from(currentPrefs.enabledPrayers);
      updatedEnabledPrayers[prayerName.toLowerCase()] = enabled;
      
      final updatedPrefs = currentPrefs.copyWith(enabledPrayers: updatedEnabledPrayers);
      await saveUserPreferences(updatedPrefs);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating prayer enabled status: $e');
      }
      rethrow;
    }
  }

  /// Update silence duration
  Future<void> updateSilenceDuration(int minutes) async {
    try {
      final currentPrefs = await getUserPreferences();
      final updatedPrefs = currentPrefs.copyWith(silenceDuration: minutes);
      await saveUserPreferences(updatedPrefs);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating silence duration: $e');
      }
      rethrow;
    }
  }

  /// Toggle app enabled status
  Future<void> toggleAppEnabled() async {
    try {
      final currentPrefs = await getUserPreferences();
      final updatedPrefs = currentPrefs.copyWith(isAppEnabled: !currentPrefs.isAppEnabled);
      await saveUserPreferences(updatedPrefs);
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling app enabled: $e');
      }
      rethrow;
    }
  }

  /// Update location coordinates
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      final currentPrefs = await getUserPreferences();
      final updatedPrefs = currentPrefs.copyWith(
        latitude: latitude,
        longitude: longitude,
      );
      await saveUserPreferences(updatedPrefs);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating location: $e');
      }
      rethrow;
    }
  }

  /// Update madhab selection
  Future<void> updateMadhab(String madhab) async {
    try {
      final currentPrefs = await getUserPreferences();
      final updatedPrefs = currentPrefs.copyWith(madhab: madhab);
      await saveUserPreferences(updatedPrefs);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating madhab: $e');
      }
      rethrow;
    }
  }

  /// Clear all stored data
  Future<void> clearAllData() async {
    try {
      final prefs = await _prefsInstance;
      await prefs.clear();
      _prefs = null; // Reset the instance
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing all data: $e');
      }
      rethrow;
    }
  }

  /// Check if preferences are initialized (for debugging)
  bool get isInitialized => _prefs != null;

  /// Initialize preferences explicitly (optional, for better control)
  Future<void> initialize() async {
    await _prefsInstance;
  }
}
