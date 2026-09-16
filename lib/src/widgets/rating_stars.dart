import 'package:flutter/material.dart';

/// Read-only star rating display shared by the patient-facing screens.
class RatingStars extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final hasRating = rating > 0;
    final labelStyle = TextStyle(
      fontSize: size - 4,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );
    final countStyle = TextStyle(fontSize: size - 4, color: Colors.grey.shade500);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final full = i < rating.floor();
          final half = !full && i < rating;
          return Icon(
            full
                ? Icons.star
                : half
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: Colors.amber.shade700,
          );
        }),
        const SizedBox(width: 4),
        Text(hasRating ? rating.toStringAsFixed(1) : '—', style: labelStyle),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text('($reviewCount)', style: countStyle),
        ],
      ],
    );
  }
}