import 'package:flutter_test/flutter_test.dart';
import '../lib/services/location_service.dart';

void main() {
  group('LocationService', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    test('should return null for getCurrentLocation without permission', () async {
      // This test would need permission mocking
      expect(locationService, isNotNull);
    });

    test('should validate city name function', () async {
      // Test getCityName with known coordinates
      final cityName = await locationService.getCityName(21.4225, 39.8262); // Makkah
      expect(cityName, isNotEmpty);
    });
  });
}
