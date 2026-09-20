import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'star_rating.dart';

class RatingDialog {
  static Future<void> show({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String role,
    required String listingId,
  }) async {
    int selectedRating = 0;
    final reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Rate $role', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience with $targetUserName?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              InteractiveStarRating(
                onRatingSelected: (rating) =>
                    setDialogState(() => selectedRating = rating),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Leave a short review (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _submitRating(
                        targetUserId,
                        selectedRating,
                        reviewController.text,
                        listingId,
                      );
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _submitRating(
    String targetUserId,
    int rating,
    String review,
    String listingId,
  ) async {
    try {
      // 1. Update Collector's Aggregate Rating (Atomic Transaction)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(
          FirebaseFirestore.instance.collection('users').doc(targetUserId),
        );
        if (userDoc.exists) {
          double currentTotal =
              (userDoc.data() as Map<String, dynamic>)['totalRating']
                  ?.toDouble() ??
              0.0;
          int count =
              (userDoc.data() as Map<String, dynamic>)['ratingCount'] ?? 0;
          double newAverage = (currentTotal + rating) / (count + 1);

          transaction.update(userDoc.reference, {
            'totalRating': FieldValue.increment(rating.toDouble()),
            'ratingCount': FieldValue.increment(1),
            'averageRating': newAverage,
          });
        }
      });

      // 2. Create Dedicated Feedback Document (CRITICAL FOR COLLECTOR HISTORY)
      await FirebaseFirestore.instance.collection('feedback').add({
        'collectorId': targetUserId,
        'householdId': FirebaseAuth.instance.currentUser!.uid,
        'listingId': listingId,
        'rating': rating,
        'comment': review,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Update Listing Denormalization (For Instant UI Updates)
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .update({
            'collectorRating': rating, // STANDARDIZED FIELD NAME
            'householdReview': review,
            'acceptedBid.rating': rating.toDouble(),
          });
    } catch (e) {
      debugPrint('Error submitting rating: $e');
    }
  }
}
