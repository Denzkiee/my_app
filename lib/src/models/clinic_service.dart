class ClinicService {
  final String? id;
  final String clinicId;
  final String name;
  final String description;

  const ClinicService({
    this.id,
    required this.clinicId,
    required this.name,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clinic_id': clinicId,
      'name': name,
      'description': description,
    };
  }

  factory ClinicService.fromMap(Map<String, dynamic> map) {
    return ClinicService(
      id: map['id'] as String?,
      clinicId: map['clinic_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
    );
  }
}
