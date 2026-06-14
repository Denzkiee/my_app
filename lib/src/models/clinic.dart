import 'clinic_availability.dart';

class Clinic {
  final String? id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String applicationStatus;
  final String adminNotes;
  final String listingStatus;
  final String statusReason;
  final String appealStatus;
  final String appealMessage;
  final DateTime? createdAt;
  final List<ClinicAvailability> availability;

  const Clinic({
    this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.applicationStatus = 'pending',
    this.adminNotes = '',
    this.listingStatus = 'active',
    this.statusReason = '',
    this.appealStatus = 'none',
    this.appealMessage = '',
    this.createdAt,
    this.availability = const [],
  });

  bool get isApproved => applicationStatus == 'approved';
  bool get isPending => applicationStatus == 'pending';
  bool get isRejected => applicationStatus == 'rejected';
  bool get isActiveListing => listingStatus == 'active';
  bool get isDisabled => listingStatus == 'disabled';
  bool get isTerminated => listingStatus == 'terminated';
  bool get isHiddenFromPatients => isApproved && !isActiveListing;
  bool get hasPendingAppeal => appealStatus == 'pending';
  bool get canSubmitAppeal =>
      isHiddenFromPatients && !hasPendingAppeal && appealStatus != 'approved';

  String get hoursSummary {
    if (availability.isEmpty) return 'Hours not set';
    final sorted = [...availability]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return sorted
        .map((slot) => '${slot.dayLabel.substring(0, 3)} ${slot.startTime}–${slot.endTime}')
        .join(' · ');
  }

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
      'listing_status': listingStatus,
      'status_reason': statusReason,
      'appeal_status': appealStatus,
      'appeal_message': appealMessage,
    };
  }

  factory Clinic.fromMap(Map<String, dynamic> map) {
    final availabilityRaw = map['clinic_availability'];
    final availability = availabilityRaw is List
        ? availabilityRaw
            .map((item) => ClinicAvailability.fromMap(item as Map<String, dynamic>))
            .toList()
        : <ClinicAvailability>[];

    return Clinic(
      id: map['id'] as String?,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      applicationStatus: map['application_status'] as String? ?? 'pending',
      adminNotes: map['admin_notes'] as String? ?? '',
      listingStatus: map['listing_status'] as String? ?? 'active',
      statusReason: map['status_reason'] as String? ?? '',
      appealStatus: map['appeal_status'] as String? ?? 'none',
      appealMessage: map['appeal_message'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      availability: availability,
    );
  }
}
