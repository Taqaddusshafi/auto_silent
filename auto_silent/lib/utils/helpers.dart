import 'package:flutter/material.dart';
import '../models/prayer_time.dart';

class AppHelpers {
  static String getPrayerDisplayName(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      default:
        return prayerName;
    }
  }

  static IconData getPrayerIcon(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.wb_sunny_outlined;
      case 'maghrib':
        return Icons.wb_twilight;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.schedule;
    }
  }

  static Color getPrayerColor(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return Colors.indigo;
      case 'dhuhr':
        return Colors.orange;
      case 'asr':
        return Colors.amber;
      case 'maghrib':
        return Colors.deepOrange;
      case 'isha':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  static String formatRemainingTime(Duration duration) {
    if (duration.isNegative) return '0m';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  static bool isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  static String getCalculationMethodDisplayName(String method) {
    const methodNames = {
      'MuslimWorldLeague': 'Muslim World League',
      'Egyptian': 'Egyptian General Authority',
      'Karachi': 'University of Islamic Sciences, Karachi',
      'UmmAlQura': 'Umm Al-Qura University, Makkah',
      'Dubai': 'The Gulf Region',
      'MoonsightingCommittee': 'Moonsighting Committee Worldwide',
      'NorthAmerica': 'Islamic Society of North America',
      'Kuwait': 'Kuwait',
      'Qatar': 'Qatar',
      'Singapore': 'Singapore',
    };
    
    return methodNames[method] ?? method;
  }

  static List<int> getSilenceDurationOptions() {
    return [5, 10, 15, 20, 25, 30, 45, 60];
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  static String getLocationString(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  static bool isPrayerTimePassed(DateTime prayerTime) {
    return DateTime.now().isAfter(prayerTime);
  }

  static PrayerTime? getNextPrayer(List<PrayerTime> prayers) {
    final now = DateTime.now();
    for (final prayer in prayers) {
      if (prayer.isEnabled && prayer.time.isAfter(now)) {
        return prayer;
      }
    }
    return null;
  }

  static PrayerTime? getCurrentPrayer(List<PrayerTime> prayers, int silenceDurationMinutes) {
    final now = DateTime.now();
    for (final prayer in prayers) {
      if (prayer.isEnabled) {
        final endTime = prayer.time.add(Duration(minutes: silenceDurationMinutes));
        if (now.isAfter(prayer.time) && now.isBefore(endTime)) {
          return prayer;
        }
      }
    }
    return null;
  }
}
