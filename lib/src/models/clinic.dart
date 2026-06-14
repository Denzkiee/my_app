class Clinic {
  final String? id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String applicationStatus;
  final String adminNotes;
  final DateTime? createdAt;

  const Clinic({
    this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.applicationStatus = 'pending',
    this.adminNotes = '',
    this.createdAt,
  });

  bool get isApproved => applicationStatus == 'approved';
  bool get isPending => applicationStatus == 'pending';
  bool get isRejected => applicationStatus == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'application_status': applicationStatus,
      'admin_notes': adminNotes,
    };
  }

  factory Clinic.fromMap(Map<String, dynamic> map) {
    return Clinic(
      id: map['id'] as String?,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      applicationStatus: map['application_status'] as String? ?? 'pending',
      adminNotes: map['admin_notes'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}
