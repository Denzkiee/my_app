import 'package:flutter/material.dart';

import '../models/clinic.dart';
import '../models/clinic_review.dart';
import '../services/database_service.dart';

/// Section heading shared by the booking screen windows.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.teal.shade700),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.teal.shade900,
          ),
        ),
      ],
    );
  }
}

/// Interactive star picker used inside [LeaveReviewCard].
class StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const StarPicker({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starValue <= rating ? Icons.star : Icons.star_border,
              color: Colors.amber.shade700,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

/// Window where the signed-in patient rates this clinic and writes feedback.
///
/// Loads the patient's existing review (if any) so the card doubles as an
/// "update your review" form. Calls [onSubmitted] after a successful save so
/// the parent screen can refresh its review list.
class LeaveReviewCard extends StatefulWidget {
  final Clinic clinic;
  final String? currentUserId;
  final Future<void> Function(int rating, String? reviewText) onSubmitted;

  const LeaveReviewCard({
    super.key,
    required this.clinic,
    required this.currentUserId,
    required this.onSubmitted,
  });

  @override
  State<LeaveReviewCard> createState() => _LeaveReviewCardState();
}

class _LeaveReviewCardState extends State<LeaveReviewCard> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _loadingExisting = true;
  bool _submitting = false;
  ClinicReview? _existingReview;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReview() async {
    final userId = widget.currentUserId;
    if (userId == null || widget.clinic.id == null) {
      if (mounted) setState(() => _loadingExisting = false);
      return;
    }
    try {
      final review = await DatabaseService.instance.fetchPatientReview(
        widget.clinic.id!,
        userId,
      );
      if (!mounted) return;
      setState(() {
        _existingReview = review;
        if (review != null) {
          _rating = review.rating;
          _reviewController.text = review.reviewText ?? '';
        }
        _loadingExisting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap a star to rate';
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final text = _reviewController.text.trim();
      await widget.onSubmitted(_rating, text.isNotEmpty ? text : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_existingReview != null
              ? 'Your review has been updated!'
              : 'Thank you for your feedback!'),
        ),
      );
      // Reload so the card flips into "update" mode.
      setState(() => _loadingExisting = true);
      await _loadExistingReview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loadingExisting
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    icon: _existingReview != null
                        ? Icons.edit_outlined
                        : Icons.rate_review_outlined,
                    title: _existingReview != null
                        ? 'Update Your Review'
                        : 'Leave a Review',
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: StarPicker(
                      rating: _rating,
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _ratingLabel,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Share your experience with this clinic...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_existingReview != null ? Icons.edit : Icons.send,
                            size: 18),
                    label: Text(_existingReview != null
                        ? 'Update Review'
                        : 'Submit Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Window listing every review for the clinic, best to worst.
///
/// The list arrives pre-sorted from [DatabaseService.fetchClinicReviews]
/// (rating desc, newest first). Shows reviewer avatar, name, date and text.
class ReviewsListCard extends StatelessWidget {
  final List<ClinicReview> reviews;

  const ReviewsListCard({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              icon: Icons.forum_outlined,
              title: 'Patient Reviews (${reviews.length})',
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No reviews yet. Be the first to share your experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              ...reviews.map((review) => _ReviewTile(review: review)),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ClinicReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  review.reviewerInitial,
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (review.createdAt != null)
                      Text(
                        _formatDate(review.createdAt!),
                        style:
                            TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber.shade700,
                  );
                }),
              ),
            ],
          ),
          if (review.reviewText != null &&
              review.reviewText!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.reviewText!.trim(),
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
