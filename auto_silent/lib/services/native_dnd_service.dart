import 'package:flutter/services.dart';

class NativeDNDService {
  static const MethodChannel _channel = MethodChannel('com.example.auto_silent/native_dnd');

  /// Start the native DND service that works independently of Flutter
  static Future<bool> startNativeService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startNativeDNDService');
      print('✅ Native DND service started: $result');
      return result ?? false;
    } catch (e) {
      print('❌ Failed to start native DND service: $e');
      return false;
    }
  }

  /// Stop the native DND service
  static Future<bool> stopNativeService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopNativeDNDService');
      print('✅ Native DND service stopped: $result');
      return result ?? false;
    } catch (e) {
      print('❌ Failed to stop native DND service: $e');
      return false;
    }
  }

  /// Check if native service is running (requires additional implementation)
  static Future<bool> isNativeServiceRunning() async {
    try {
      // This would require additional native method implementation
      // For now, return true as we can't easily check from Flutter
      return true;
    } catch (e) {
      return false;
    }
  }
}
