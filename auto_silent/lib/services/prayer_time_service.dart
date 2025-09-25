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

  // FIXED: Convert string madhab to Adhan package Madhab enum
  // Only supports: hanafi, shafi (not hanbali, jafari as they're not in Adhan package)
  Madhab _getMadhab(String madhab) {
    switch (madhab.toLowerCase()) {
      case 'hanafi':
        return Madhab.hanafi;
      case 'shafi':
      case 'shafii':
      case 'shafi\'i':
      case 'hanbali': // Map to shafi as fallback
      case 'maliki':  // Map to shafi as fallback
      case 'jafari':  // Map to shafi as fallback
        return Madhab.shafi;
      default:
        return Madhab.shafi; // Default to Shafi
    }
  }

  // FIXED: Updated calculation method mapping to match Adhan package
  CalculationParameters _getCalculationParams(String method) {
    switch (method) {
      case 'MuslimWorldLeague':
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'Egyptian':
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'Karachi':
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'UmmAlQura':
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'Dubai':
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'MoonsightingCommittee':
      case 'moonsighting_committee':
        return CalculationMethod.moon_sighting_committee.getParameters();
      case 'NorthAmerica':
      case 'north_america':
        return CalculationMethod.north_america.getParameters();
      case 'Kuwait':
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'Qatar':
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'Singapore':
      case 'singapore':
        return CalculationMethod.singapore.getParameters();
      case 'Turkey':
      case 'turkey':
        return CalculationMethod.turkey.getParameters();
      case 'Tehran':
      case 'tehran':
        return CalculationMethod.tehran.getParameters();
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

  // FIXED: Get the name of current madhab in a readable format
  String getMadhabDisplayName(String madhab) {
    switch (madhab.toLowerCase()) {
      case 'hanafi':
        return 'Hanafi (حنفی)';
      case 'shafi':
      case 'shafii':
      case 'shafi\'i':
        return 'Shafi\'i (شافعی)';
      case 'hanbali':
        return 'Hanbali (حنبلی) - Mapped to Shafi\'i';
      case 'maliki':
        return 'Maliki (مالکی) - Mapped to Shafi\'i';
      case 'jafari':
        return 'Jafari (جعفری) - Mapped to Shafi\'i';
      default:
        return 'Shafi\'i (شافعی)';
    }
  }

  // NEW: Get available calculation methods
  List<Map<String, String>> getAvailableCalculationMethods() {
    return [
      {'key': 'muslim_world_league', 'name': 'Muslim World League'},
      {'key': 'egyptian', 'name': 'Egyptian General Authority'},
      {'key': 'karachi', 'name': 'University of Islamic Sciences, Karachi'},
      {'key': 'umm_al_qura', 'name': 'Umm al-Qura University, Makkah'},
      {'key': 'dubai', 'name': 'Dubai (UAE)'},
      {'key': 'qatar', 'name': 'Qatar'},
      {'key': 'kuwait', 'name': 'Kuwait'},
      {'key': 'moonsighting_committee', 'name': 'Moonsighting Committee'},
      {'key': 'singapore', 'name': 'Singapore'},
      {'key': 'north_america', 'name': 'ISNA (North America)'},
      {'key': 'turkey', 'name': 'Turkey'},
      {'key': 'tehran', 'name': 'Tehran'},
    ];
  }

  // NEW: Get available madhabs (only the ones supported by Adhan package)
  List<Map<String, String>> getAvailableMadhabs() {
    return [
      {'key': 'shafi', 'name': 'Shafi\'i (شافعی) - Earlier Asr'},
      {'key': 'hanafi', 'name': 'Hanafi (حنفی) - Later Asr'},
    ];
  }

  // NEW: Validate coordinates
  bool isValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  // NEW: Get Qibla direction
  Future<double?> getQiblaDirection() async {
    try {
      final prefs = await _storageService.getUserPreferences();
      
      if (prefs.latitude == 0.0 || prefs.longitude == 0.0) {
        return null;
      }

      final coordinates = Coordinates(prefs.latitude, prefs.longitude);
      final qibla = Qibla(coordinates);
      return qibla.direction;
    } catch (e) {
      return null;
    }
  }

  // NEW: Get Sunnah times
  Future<Map<String, DateTime>?> getSunnahTimes() async {
    try {
      final prayerTimes = await getTodaysPrayerTimes();
      final prefs = await _storageService.getUserPreferences();
      
      final coordinates = Coordinates(prefs.latitude, prefs.longitude);
      final date = DateComponents.from(DateTime.now());
      final params = _getCalculationParams(prefs.calculationMethod);
      params.madhab = _getMadhab(prefs.madhab);
      
      final adhanPrayerTimes = PrayerTimes.today(coordinates, params);
      final sunnahTimes = SunnahTimes(adhanPrayerTimes);
      
      return {
        'middleOfTheNight': sunnahTimes.middleOfTheNight,
        'lastThirdOfTheNight': sunnahTimes.lastThirdOfTheNight,
      };
    } catch (e) {
      return null;
    }
  }
}
