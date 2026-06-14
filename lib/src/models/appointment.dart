class Appointment {
  final String? id;
  final String patientId;
  final String clinicId;
  final String? serviceId;
  final String serviceName;
  final DateTime appointmentDateTime;
  final String contactNumber;
  final String notes;
  final String status;
  final String? clinicName;
  final String? patientName;

  const Appointment({
    this.id,
    required this.patientId,
    required this.clinicId,
    this.serviceId,
    required this.serviceName,
    required this.appointmentDateTime,
    required this.contactNumber,
    this.notes = '',
    this.status = 'pending',
    this.clinicName,
    this.patientName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'clinic_id': clinicId,
      if (serviceId != null) 'service_id': serviceId,
      'service_name': serviceName,
      'appointment_datetime': appointmentDateTime.toUtc().toIso8601String(),
      'contact_number': contactNumber,
      'notes': notes,
      'status': status,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final clinics = map['clinics'];
    final profiles = map['profiles'];

    return Appointment(
      id: map['id'] as String?,
      patientId: map['patient_id'] as String,
      clinicId: map['clinic_id'] as String,
      serviceId: map['service_id'] as String?,
      serviceName: map['service_name'] as String,
      appointmentDateTime: DateTime.parse(map['appointment_datetime'] as String).toLocal(),
      contactNumber: map['contact_number'] as String,
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      clinicName: clinics is Map ? clinics['name'] as String? : null,
      patientName: profiles is Map ? profiles['full_name'] as String? : null,
    );
  }
}
