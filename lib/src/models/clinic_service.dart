class ClinicService {
  final String? id;
  final String clinicId;
  final String name;
  final String description;
  final double price;

  const ClinicService({
    this.id,
    required this.clinicId,
    required this.name,
    this.description = '',
    this.price = 0,
  });

  String get priceLabel => '₱${price.toStringAsFixed(2)}';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'clinic_id': clinicId,
      'name': name,
      'description': description,
      'price': price,
    };
  }

  factory ClinicService.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final parsedPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '0') ?? 0;

    return ClinicService(
      id: map['id'] as String?,
      clinicId: map['clinic_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: parsedPrice,
    );
  }
}
