class ClinicReview {
  final String? id;
  final String clinicId;
  final String patientId;
  final int rating;
  final String? reviewText;
  final DateTime? createdAt;

  const ClinicReview({
    this.id,
    required this.clinicId,
    required this.patientId,
    required this.rating,
    this.reviewText,
    this.createdAt,
  });

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
    return ClinicReview(
      id: map['id'] as String?,
      clinicId: map['clinic_id'] as String,
      patientId: map['patient_id'] as String,
      rating: map['rating'] as int,
      reviewText: map['review_text'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}