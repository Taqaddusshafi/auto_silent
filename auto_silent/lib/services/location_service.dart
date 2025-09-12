import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart'; // Add this import
import 'storage_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StorageService _storageService = StorageService();

  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission == PermissionStatus.granted;
  }

  Future<bool> isLocationPermissionGranted() async {
    final permission = await Permission.location.status;
    return permission == PermissionStatus.granted;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await isLocationPermissionGranted();
      if (!hasPermission) {
        final granted = await requestLocationPermission();
        if (!granted) return null;
      }

      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        throw Exception('Location services are disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Save location to preferences
      final prefs = await _storageService.getUserPreferences();
      final updatedPrefs = prefs.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _storageService.saveUserPreferences(updatedPrefs);

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<void> updateLocationInPreferences(double latitude, double longitude) async {
    final prefs = await _storageService.getUserPreferences();
    final updatedPrefs = prefs.copyWith(
      latitude: latitude,
      longitude: longitude,
    );
    await _storageService.saveUserPreferences(updatedPrefs);
  }

  Future<String> getCityName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.locality ?? placemark.administrativeArea ?? 'Unknown';
      }
    } catch (e) {
      print('Error getting city name: $e');
    }
    return 'Unknown Location';
  }

  Future<Map<String, double>?> getSavedLocation() async {
    final prefs = await _storageService.getUserPreferences();
    if (prefs.latitude != 0.0 && prefs.longitude != 0.0) {
      return {
        'latitude': prefs.latitude,
        'longitude': prefs.longitude,
      };
    }
    return null;
  }
}
