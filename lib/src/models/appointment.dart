class Appointment {
  final String? id;
  final String? userId;
  final String patientName;
  final String serviceType;
  final String dentistName;
  final DateTime dateTime;
  final String contactNumber;
  final String notes;
  final String status;

  Appointment({
    this.id,
    this.userId,
    required this.patientName,
    required this.serviceType,
    required this.dentistName,
    required this.dateTime,
    required this.contactNumber,
    required this.notes,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': userId,
      'patient_name': patientName,
      'service_type': serviceType,
      'dentist_name': dentistName,
      'date_time': dateTime.toIso8601String(),
      'contact_number': contactNumber,
      'notes': notes,
      'status': status,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as String?,
      userId: map['profile_id'] as String?,
      patientName: map['patient_name'] as String,
      serviceType: map['service_type'] as String,
      dentistName: map['dentist_name'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
      contactNumber: map['contact_number'] as String,
      notes: map['notes'] as String,
      status: map['status'] as String,
    );
  }
}
