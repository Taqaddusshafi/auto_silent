class PrayerTime {
  final String name;
  final DateTime time;
  final bool isEnabled;

  PrayerTime({
    required this.name,
    required this.time,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time.millisecondsSinceEpoch,
      'isEnabled': isEnabled,
    };
  }

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      name: json['name'],
      time: DateTime.fromMillisecondsSinceEpoch(json['time']),
      isEnabled: json['isEnabled'],
    );
  }

  PrayerTime copyWith({
    String? name,
    DateTime? time,
    bool? isEnabled,
  }) {
    return PrayerTime(
      name: name ?? this.name,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  String toString() {
    return 'PrayerTime{name: $name, time: $time, isEnabled: $isEnabled}';
  }
}

enum Prayer {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha,
}

extension PrayerExtension on Prayer {
  String get name {
    switch (this) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
    }
  }
}
