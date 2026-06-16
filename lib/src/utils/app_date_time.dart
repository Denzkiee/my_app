import 'package:intl/intl.dart';

/// Philippine Standard Time (UTC+8, no DST).
class AppDateTime {
  AppDateTime._();

  static const phOffset = Duration(hours: 8);
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateTimeFormat = DateFormat('MMM d, yyyy • hh:mm a');

  static DateTime philippineNow() => DateTime.now().toUtc().add(phOffset);

  static DateTime toPhilippine(DateTime dateTime) => dateTime.toUtc().add(phOffset);

  static String formatDate(DateTime dateTime) =>
      _dateFormat.format(toPhilippine(dateTime));

  static String formatTime(DateTime dateTime) =>
      _timeFormat.format(toPhilippine(dateTime));

  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(toPhilippine(dateTime));

  static String formatTimeRange(String start, String end) {
    final startFormatted = formatClockTime(start);
    final endFormatted = formatClockTime(end);
    return '$startFormatted – $endFormatted';
  }

  static String formatClockTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final date = DateTime(2000, 1, 1, hour, minute);
    return _timeFormat.format(date);
  }

  static String timezoneLabel() => 'Philippine Time (PHT)';
}
