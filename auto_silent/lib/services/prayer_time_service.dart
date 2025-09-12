import 'package:adhan/adhan.dart';
import '../models/prayer_time.dart';
import '../models/user_preferences.dart';
import 'storage_service.dart';

class PrayerTimeService {
  static final PrayerTimeService _instance = PrayerTimeService._internal();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._internal();

  final StorageService _storageService = StorageService();

  Future<List<PrayerTime>> getTodaysPrayerTimes() async {
    final prefs = await _storageService.getUserPreferences();
    
    if (prefs.latitude == 0.0 || prefs.longitude == 0.0) {
      throw Exception('Location not set');
    }

    final coordinates = Coordinates(prefs.latitude, prefs.longitude);
    final date = DateComponents.from(DateTime.now());
    final params = _getCalculationParams(prefs.calculationMethod);
    
    // Set madhab based on user preference
    params.madhab = _getMadhab(prefs.madhab);
    
    final prayerTimes = PrayerTimes.today(coordinates, params);
    
    return [
      PrayerTime(
        name: 'Fajr',
        time: prayerTimes.fajr,
        isEnabled: prefs.enabledPrayers['fajr'] ?? true,
      ),
      PrayerTime(
        name: 'Dhuhr',
        time: prayerTimes.dhuhr,
        isEnabled: prefs.enabledPrayers['dhuhr'] ?? true,
      ),
      PrayerTime(
        name: 'Asr',
        time: prayerTimes.asr,
        isEnabled: prefs.enabledPrayers['asr'] ?? true,
      ),
      PrayerTime(
        name: 'Maghrib',
        time: prayerTimes.maghrib,
        isEnabled: prefs.enabledPrayers['maghrib'] ?? true,
      ),
      PrayerTime(
        name: 'Isha',
        time: prayerTimes.isha,
        isEnabled: prefs.enabledPrayers['isha'] ?? true,
      ),
    ];
  }

  Future<PrayerTime?> getCurrentPrayerTime() async {
    final prayerTimes = await getTodaysPrayerTimes();
    final prefs = await _storageService.getUserPreferences();
    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      if (prayer.isEnabled && _isWithinSilenceWindow(prayer.time, now, prefs.silenceDuration)) {
        return prayer;
      }
    }
    return null;
  }

  Future<PrayerTime?> getNextPrayerTime() async {
    final prayerTimes = await getTodaysPrayerTimes();
    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      if (prayer.isEnabled && prayer.time.isAfter(now)) {
        return prayer;
      }
    }
    
    // If no prayer left today, get tomorrow's first prayer
    return await _getTomorrowsFirstPrayer();
  }

  Future<PrayerTime?> _getTomorrowsFirstPrayer() async {
    try {
      final prefs = await _storageService.getUserPreferences();
      final coordinates = Coordinates(prefs.latitude, prefs.longitude);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date = DateComponents.from(tomorrow);
      final params = _getCalculationParams(prefs.calculationMethod);
      params.madhab = _getMadhab(prefs.madhab);
      
      final prayerTimes = PrayerTimes(coordinates, date, params);
      
      final tomorrowPrayers = [
        PrayerTime(name: 'Fajr', time: prayerTimes.fajr, isEnabled: prefs.enabledPrayers['fajr'] ?? true),
        PrayerTime(name: 'Dhuhr', time: prayerTimes.dhuhr, isEnabled: prefs.enabledPrayers['dhuhr'] ?? true),
        PrayerTime(name: 'Asr', time: prayerTimes.asr, isEnabled: prefs.enabledPrayers['asr'] ?? true),
        PrayerTime(name: 'Maghrib', time: prayerTimes.maghrib, isEnabled: prefs.enabledPrayers['maghrib'] ?? true),
        PrayerTime(name: 'Isha', time: prayerTimes.isha, isEnabled: prefs.enabledPrayers['isha'] ?? true),
      ];
      
      return tomorrowPrayers.firstWhere((prayer) => prayer.isEnabled);
    } catch (e) {
      return null;
    }
  }

  bool _isWithinSilenceWindow(DateTime prayerTime, DateTime currentTime, int silenceDurationMinutes) {
    final silenceEndTime = prayerTime.add(Duration(minutes: silenceDurationMinutes));
    return currentTime.isAfter(prayerTime) && currentTime.isBefore(silenceEndTime);
  }

  // Convert string madhab to Adhan package Madhab enum
  // Only supports: hanafi, shafi, hanbali, jafari (maliki not supported by Adhan package)
  Madhab _getMadhab(String madhab) {
    switch (madhab.toLowerCase()) {
      case 'hanafi':
        return Madhab.hanafi;
      case 'shafi':
      case 'shafii':
        return Madhab.shafi;
      default:
        return Madhab.shafi; // Default to Shafi
    }
  }

  CalculationParameters _getCalculationParams(String method) {
    switch (method) {
      case 'MuslimWorldLeague':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'Egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'Karachi':
        return CalculationMethod.karachi.getParameters();
      case 'UmmAlQura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'Dubai':
        return CalculationMethod.dubai.getParameters();
      case 'MoonsightingCommittee':
        return CalculationMethod.moon_sighting_committee.getParameters();
      case 'NorthAmerica':
        return CalculationMethod.north_america.getParameters();
      case 'Kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'Qatar':
        return CalculationMethod.qatar.getParameters();
      case 'Singapore':
        return CalculationMethod.singapore.getParameters();
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }

  Future<Duration> getTimeUntilNextPrayer() async {
    final nextPrayer = await getNextPrayerTime();
    if (nextPrayer == null) return Duration.zero;
    
    final remaining = nextPrayer.time.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<bool> shouldSilenceNow() async {
    final currentPrayer = await getCurrentPrayerTime();
    return currentPrayer != null;
  }

  // Get prayer times for a specific date
  Future<List<PrayerTime>> getPrayerTimesForDate(DateTime date) async {
    final prefs = await _storageService.getUserPreferences();
    
    if (prefs.latitude == 0.0 || prefs.longitude == 0.0) {
      throw Exception('Location not set');
    }

    final coordinates = Coordinates(prefs.latitude, prefs.longitude);
    final dateComponents = DateComponents.from(date);
    final params = _getCalculationParams(prefs.calculationMethod);
    params.madhab = _getMadhab(prefs.madhab);
    
    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    
    return [
      PrayerTime(name: 'Fajr', time: prayerTimes.fajr, isEnabled: prefs.enabledPrayers['fajr'] ?? true),
      PrayerTime(name: 'Dhuhr', time: prayerTimes.dhuhr, isEnabled: prefs.enabledPrayers['dhuhr'] ?? true),
      PrayerTime(name: 'Asr', time: prayerTimes.asr, isEnabled: prefs.enabledPrayers['asr'] ?? true),
      PrayerTime(name: 'Maghrib', time: prayerTimes.maghrib, isEnabled: prefs.enabledPrayers['maghrib'] ?? true),
      PrayerTime(name: 'Isha', time: prayerTimes.isha, isEnabled: prefs.enabledPrayers['isha'] ?? true),
    ];
  }

  // Get remaining silence time for current prayer
  Future<Duration?> getRemainingPrayerSilenceTime() async {
    final currentPrayer = await getCurrentPrayerTime();
    if (currentPrayer == null) return null;

    final prefs = await _storageService.getUserPreferences();
    final silenceEndTime = currentPrayer.time.add(Duration(minutes: prefs.silenceDuration));
    final remaining = silenceEndTime.difference(DateTime.now());
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Check if a specific prayer time has passed
  bool hasPrayerTimePassed(DateTime prayerTime) {
    return DateTime.now().isAfter(prayerTime);
  }

  // Get the name of current madhab in a readable format
  String getMadhabDisplayName(String madhab) {
    switch (madhab.toLowerCase()) {
      case 'hanafi':
        return 'Hanafi (حنفی)';
      case 'shafi':
        return 'Shafi\'i (شافعی)';
      case 'hanbali':
        return 'Hanbali (حنبلی)';
      case 'jafari':
        return 'Jafari (جعفری)';
      default:
        return 'Shafi\'i (شافعی)';
    }
  }
}
