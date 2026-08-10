import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rate $role', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How was your experience with $targetUserName?', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              InteractiveStarRating(
                onRatingSelected: (rating) => setDialogState(() => selectedRating = rating), // Updates the button instantly
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Leave a short review (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              // Button is disabled until selectedRating is > 0
              onPressed: selectedRating == 0 ? null : () async {
                Navigator.pop(context);
                await _submitRating(targetUserId, selectedRating, reviewController.text, listingId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _submitRating(String targetUserId, int rating, String review, String listingId) async {
    try {
      // 1. Update the Collector's average rating in the users collection
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(
          FirebaseFirestore.instance.collection('users').doc(targetUserId),
        );
        
        if (userDoc.exists) {
          double currentTotal = (userDoc.data() as Map)['totalRating']?.toDouble() ?? 0.0;
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

      // 2. Save the rating to the specific listing so the "Rate" button turns into stars
      await FirebaseFirestore.instance.collection('listings').doc(listingId).update({
        'householdRating': rating,
        'householdReview': review,
      });
      
    } catch (e) {
      debugPrint('❌ Error submitting rating: $e');
    }
  }
}
