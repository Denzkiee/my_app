class ClinicReview {
  final String? id;
  final String clinicId;
  final String patientId;
  final int rating;
  final String? reviewText;
  final DateTime? createdAt;

  /// Reviewer display name, populated when the query joins `profiles(full_name)`.
  final String? patientName;

  const ClinicReview({
    this.id,
    required this.clinicId,
    required this.patientId,
    required this.rating,
    this.reviewText,
    this.createdAt,
    this.patientName,
  });

  /// Name to show for the reviewer, falling back to a generic label.
  String get reviewerLabel {
    final name = patientName?.trim() ?? '';
    return name.isEmpty ? 'Anonymous patient' : name;
  }

  /// First letter used for the reviewer avatar.
  String get reviewerInitial {
    final label = reviewerLabel;
    return label.isEmpty ? '?' : label[0].toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'rating': rating,
      if (reviewText != null) 'review_text': reviewText,
    };
  }

  factory ClinicReview.fromMap(Map<String, dynamic> map) {
    final profiles = map['profiles'];

    return ClinicReview(
      id: map['id'] as String?,
      clinicId: map['clinic_id'] as String,
      patientId: map['patient_id'] as String,
      rating: map['rating'] as int,
      reviewText: map['review_text'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      patientName: profiles is Map ? profiles['full_name'] as String? : null,
    );
  }
}