import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/prayer_time.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // UPDATED: Remove icon reference to avoid showing icons
    const androidSettings = AndroidInitializationSettings('app_icon'); // Use default app icon
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await createNotificationChannels();
    await requestNotificationPermission();
  }

  /// NEW: Create notification channels for better control
  Future<void> createNotificationChannels() async {
    // Silent notification channel (no icon, no sound)
    const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
      'salah_silence',
      'Salah Silence Mode',
      description: 'Silent notifications for prayer time silence mode',
      importance: Importance.low, // Low importance = no sound
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    // Prayer time notification channel (with sound)
    const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
      'prayer_times',
      'Prayer Times',
      description: 'Prayer time notifications with sound',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Prayer reminder channel
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'prayer_reminder',
      'Prayer Reminders',
      description: 'Upcoming prayer reminders',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: false,
      showBadge: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(silentChannel);
    
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(prayerChannel);
        
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(reminderChannel);
  }

  Future<bool> requestNotificationPermission() async {
    final permission = await Permission.notification.request();
    return permission == PermissionStatus.granted;
  }

  /// UPDATED: Show silence mode notification WITHOUT icon
  Future<void> showSilenceModeNotification({PrayerTime? prayer}) async {
    // UPDATED: Silent notification details - NO ICON, NO SOUND
    const androidDetails = AndroidNotificationDetails(
      'salah_silence',
      'Salah Silence Mode',
      channelDescription: 'Silent notifications for prayer time silence mode',
      importance: Importance.low, // Low importance = no sound/vibration
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false, // Explicitly disable sound
      enableVibration: false, // Explicitly disable vibration
      showWhen: false, // Don't show timestamp
      // NO icon parameter = uses default minimal notification appearance
    );

    // iOS settings for silent notification
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false, // No badge
      presentSound: false, // No sound
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use prayer details if provided, otherwise show generic message
    final String title = prayer != null ? '🔇 ${prayer.name} Prayer' : '🔇 Prayer Time';
    final String body = prayer != null 
        ? 'Silent mode active for ${prayer.name}'
        : 'Silent mode active';

    await _notifications.show(
      1001, // unique notification ID for silence mode
      title,
      body,
      notificationDetails,
    );
  }

  /// Prayer time notification (with sound and icon)
  Future<void> showPrayerTimeNotification(PrayerTime prayer) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_times',
      'Prayer Times',
      channelDescription: 'Prayer time notifications',
      importance: Importance.high,
      priority: Priority.high,
      // sound: RawResourceAndroidNotificationSound('adhan'), // Comment out if no custom sound
      enableVibration: true,
      icon: '@mipmap/ic_launcher', // Use app icon for prayer notifications
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // sound: 'adhan.mp3', // Comment out if no custom sound file
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      prayer.name.hashCode, // unique ID for each prayer
      '🕌 ${prayer.name} Prayer Time',
      'It\'s time for ${prayer.name} prayer',
      notificationDetails,
    );
  }

  /// UPDATED: Show simple text-only notification
  Future<void> showTextOnlyNotification(String title, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'salah_silence',
      'Simple Notifications',
      channelDescription: 'Text-only notifications',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
      title,
      message,
      notificationDetails,
    );
  }

  /// Cancel silence mode notification
  Future<void> cancelSilenceModeNotification() async {
    await _notifications.cancel(1001);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Schedule prayer reminder notification
  Future<void> scheduleNextPrayerNotification(PrayerTime prayer) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_reminder',
      'Prayer Reminders',
      channelDescription: 'Upcoming prayer reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert DateTime to TZDateTime
    final scheduledTime = _convertToTZDateTime(prayer.time.subtract(const Duration(minutes: 5)));

    await _notifications.zonedSchedule(
      prayer.name.hashCode + 1000, // unique ID for reminders
      '🕌 Upcoming Prayer',
      '${prayer.name} prayer in 5 minutes',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Helper method to convert DateTime to TZDateTime
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    final location = tz.local;
    return tz.TZDateTime.from(dateTime, location);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }
}
