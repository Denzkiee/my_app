class ClinicAvailability {
  final String? id;
  final String clinicId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int slotDurationMinutes;

  const ClinicAvailability({
    this.id,
    required this.clinicId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.slotDurationMinutes = 30,
  });

  static const dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String get dayLabel => dayNames[dayOfWeek];

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clinic_id': clinicId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'slot_duration_minutes': slotDurationMinutes,
    };
  }

  factory ClinicAvailability.fromMap(Map<String, dynamic> map) {
    return ClinicAvailability(
      id: map['id'] as String?,
      clinicId: map['clinic_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: _normalizeTime(map['start_time']),
      endTime: _normalizeTime(map['end_time']),
      slotDurationMinutes: map['slot_duration_minutes'] as int? ?? 30,
    );
  }

  static String _normalizeTime(dynamic value) {
    final raw = value.toString();
    if (raw.length >= 5) return raw.substring(0, 5);
    return raw;
  }

  int get dartWeekday => dayOfWeek == 0 ? 7 : dayOfWeek;

  List<DateTime> slotsForDate(DateTime date) {
    if (date.weekday != dartWeekday) return [];

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    final slots = <DateTime>[];
    var cursor = start;
    while (cursor.isBefore(end)) {
      if (cursor.isAfter(DateTime.now())) {
        slots.add(cursor);
      }
      cursor = cursor.add(Duration(minutes: slotDurationMinutes));
    }
    return slots;
  }
}
