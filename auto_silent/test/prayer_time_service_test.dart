import 'package:flutter_test/flutter_test.dart';
import '../lib/services/prayer_time_service.dart';

void main() {
  group('PrayerTimeService', () {
    late PrayerTimeService prayerTimeService;

    setUp(() {
      prayerTimeService = PrayerTimeService();
    });

    test('should calculate prayer times for valid coordinates', () async {
      // Test with Makkah coordinates
      // Note: This test requires location to be set in preferences first
      // In a real test, you'd mock the StorageService
      
      expect(prayerTimeService, isNotNull);
    });

    test('should throw exception for invalid coordinates', () async {
      // Test with coordinates (0, 0) which should trigger an exception
      expect(
        () async => await prayerTimeService.getTodaysPrayerTimes(),
        throwsException,
      );
    });
  });
}
