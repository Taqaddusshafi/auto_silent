class UserPreferences {
  final bool isAppEnabled;
  final int silenceDuration; 
  final double latitude;
  final double longitude;
  final String calculationMethod;
  final String madhab; // Add this field
  final Map<String, bool> enabledPrayers;
  final bool notificationsEnabled;
  final bool vibrateOnSilenceStart;
  final bool showPrayerNotifications;

  UserPreferences({
    this.isAppEnabled = true,
    this.silenceDuration = 20,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.calculationMethod = 'MuslimWorldLeague',
    this.madhab = 'Shafi', // Default to Shafi
    this.enabledPrayers = const {
      'fajr': true,
      'dhuhr': true,
      'asr': true,
      'maghrib': true,
      'isha': true,
    },
    this.notificationsEnabled = true,
    this.vibrateOnSilenceStart = true,
    this.showPrayerNotifications = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'isAppEnabled': isAppEnabled,
      'silenceDuration': silenceDuration,
      'latitude': latitude,
      'longitude': longitude,
      'calculationMethod': calculationMethod,
      'madhab': madhab, // Add this
      'enabledPrayers': enabledPrayers,
      'notificationsEnabled': notificationsEnabled,
      'vibrateOnSilenceStart': vibrateOnSilenceStart,
      'showPrayerNotifications': showPrayerNotifications,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      isAppEnabled: json['isAppEnabled'] ?? true,
      silenceDuration: json['silenceDuration'] ?? 20,
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      calculationMethod: json['calculationMethod'] ?? 'MuslimWorldLeague',
      madhab: json['madhab'] ?? 'Shafi', // Add this
      enabledPrayers: Map<String, bool>.from(json['enabledPrayers'] ?? {}),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      vibrateOnSilenceStart: json['vibrateOnSilenceStart'] ?? true,
      showPrayerNotifications: json['showPrayerNotifications'] ?? true,
    );
  }

  UserPreferences copyWith({
    bool? isAppEnabled,
    int? silenceDuration,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    String? madhab, // Add this parameter
    Map<String, bool>? enabledPrayers,
    bool? notificationsEnabled,
    bool? vibrateOnSilenceStart,
    bool? showPrayerNotifications,
  }) {
    return UserPreferences(
      isAppEnabled: isAppEnabled ?? this.isAppEnabled,
      silenceDuration: silenceDuration ?? this.silenceDuration,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab, // Add this
      enabledPrayers: enabledPrayers ?? this.enabledPrayers,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      vibrateOnSilenceStart: vibrateOnSilenceStart ?? this.vibrateOnSilenceStart,
      showPrayerNotifications: showPrayerNotifications ?? this.showPrayerNotifications,
    );
  }
}
