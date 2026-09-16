import 'clinic_availability.dart';
import '../utils/app_date_time.dart';

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
  final double avgRating;
  final int reviewCount;
  final double? latitude;
  final double? longitude;
  final List<String> establishmentImages;
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
    this.avgRating = 0,
    this.reviewCount = 0,
    this.latitude,
    this.longitude,
    this.establishmentImages = const [],
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
        .map((slot) => '${slot.dayLabel.substring(0, 3)} ${AppDateTime.formatTimeRange(slot.startTime, slot.endTime)}')
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (establishmentImages.isNotEmpty) 'establishment_images': establishmentImages,
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
      avgRating: (map['avg_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['review_count'] as int?) ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      establishmentImages: _parseEstablishmentImages(map['establishment_images']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      availability: availability,
    );
  }

  /// Safely parses the `establishment_images` column.
  ///
  /// Supabase stores this as `text[]`, but defensive parsing is needed if the
  /// column contains non-string values (mis-typed column, JSON blob, numeric
  /// leftovers, etc.) so the app never crashes on `fromMap`.
  static List<String> _parseEstablishmentImages(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];

    final seenNonString = <dynamic>[];
    final out = <String>[];

    for (final item in raw) {
      if (item is String) {
        if (item.isNotEmpty) out.add(item);
      } else if (item != null) {
        seenNonString.add(item);
      }
    }

    // In debug builds, surface bad data loudly so the root cause isn't silent.
    if (seenNonString.isNotEmpty) {
      assert(false,
          'Clinic.establishment_images contained non-String entries: $seenNonString. '
          'Dropped them. Check Supabase column type and image upload path.');
    }

    return out;
  }

  /// Returns true if the clinic has valid coordinates for map display
  bool get hasValidLocation => latitude != null && longitude != null;

  /// Returns true if the clinic has uploaded establishment images
  bool get hasEstablishmentImages => establishmentImages.isNotEmpty;
}
