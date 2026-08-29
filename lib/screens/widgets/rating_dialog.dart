import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'star_rating.dart';

// ============================================================================
// CLASS DEFINITION
// ============================================================================

// THIS CLASS DEFINES A REUSABLE RATING DIALOG.
// IT ALLOWS USERS TO RATE AND REVIEW ANOTHER USER (E.G., A COLLECTOR)
// AND UPDATES BOTH THE USER'S AVERAGE RATING AND THE SPECIFIC LISTING RECORD.
class RatingDialog {
  /// THIS METHOD DISPLAYS THE RATING DIALOG.
  /// IT TAKES THE CONTEXT, TARGET USER DETAILS, ROLE, AND LISTING ID.
  /// IT USES A STATEFULBUILDER TO INSTANTLY UPDATE THE UI WHEN STARS ARE SELECTED.
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
                // UPDATES THE BUTTON STATE INSTANTLY WHEN A RATING IS SELECTED
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
              // BUTTON IS DISABLED UNTIL SELECTEDRATING IS GREATER THAN 0
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

  /// THIS METHOD HANDLES SUBMITTING THE RATING TO FIRESTORE.
  /// IT USES A TRANSACTION TO SAFELY UPDATE THE TARGET USER'S AVERAGE RATING
  /// AND THEN UPDATES THE SPECIFIC LISTING DOCUMENT TO RECORD THAT IT HAS BEEN RATED.
  static Future<void> _submitRating(
    String targetUserId,
    int rating,
    String review,
    String listingId,
  ) async {
    try {
      // 1. UPDATE THE TARGET USER'S AVERAGE RATING IN THE USERS COLLECTION USING A TRANSACTION
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(
          FirebaseFirestore.instance.collection('users').doc(targetUserId),
        );

        if (userDoc.exists) {
          double currentTotal =
              (userDoc.data() as Map)['totalRating']?.toDouble() ?? 0.0;
          int count = (userDoc.data() as Map)['ratingCount'] ?? 0;

          double newTotal = currentTotal + rating;
          int newCount = count + 1;
          double newAverage = newTotal / newCount;

          transaction.update(userDoc.reference, {
            'totalRating': newTotal,
            'ratingCount': newCount,
            'averageRating': newAverage,
          });
        }
      });

      // 2. SAVE THE RATING TO THE SPECIFIC LISTING SO THE UI REFLECTS THAT IT HAS BEEN RATED
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .update({'householdRating': rating, 'householdReview': review});
    } catch (e) {
      debugPrint('Error submitting rating: $e');
    }
  }
}
