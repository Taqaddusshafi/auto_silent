import 'package:intl/intl.dart';

class DateTimeUtils {
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('EEEE, MMMM d, y').format(dateTime);
  }

  static String formatShortDate(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '0m';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatTimeUntil(DateTime targetTime) {
    final now = DateTime.now();
    final difference = targetTime.difference(now);
    
    if (difference.isNegative) {
      return 'Passed';
    }
    
    return formatDuration(difference);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  static String getRelativeDayString(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else if (isYesterday(date)) {
      return 'Yesterday';
    } else {
      return formatShortDate(date);
    }
  }

  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static List<DateTime> getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = getStartOfDay(start);
    final endDay = getStartOfDay(end);

    while (!current.isAfter(endDay)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  static int daysBetween(DateTime start, DateTime end) {
    final startDay = getStartOfDay(start);
    final endDay = getStartOfDay(end);
    return endDay.difference(startDay).inDays;
  }

  static DateTime addMinutes(DateTime dateTime, int minutes) {
    return dateTime.add(Duration(minutes: minutes));
  }

  static DateTime subtractMinutes(DateTime dateTime, int minutes) {
    return dateTime.subtract(Duration(minutes: minutes));
  }

  static String formatTimeWithSeconds(DateTime dateTime) {
    return DateFormat('h:mm:ss a').format(dateTime);
  }

  static String format24Hour(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatISO8601(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  static DateTime parseISO8601(String dateString) {
    return DateTime.parse(dateString);
  }
}
