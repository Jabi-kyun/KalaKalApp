import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// WIDGET CLASS
// ============================================================================

class PlaceBidPage extends StatefulWidget {
  final String listingId;
  final String category;
  final String quantity;
  final String description;
  final String householdName;

  const PlaceBidPage({
    super.key,
    required this.listingId,
    required this.category,
    required this.quantity,
    required this.description,
    required this.householdName,
  });

  @override
  State<PlaceBidPage> createState() => _PlaceBidPageState();
}

class _PlaceBidPageState extends State<PlaceBidPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the text input for the bid amount and the loading state
  // ==========================================================================

  final _amountController = TextEditingController();
  bool _isLoading = false;

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void dispose() {
    // Cleans up memory by disposing the text controller when the page is closed
    _amountController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR SUBMITTING A BID TO A LISTING.
  /// It validates that the entered amount is a valid positive number, fetches the
  /// collector's current name and rating from their user profile, constructs a new
  /// bid object, and safely appends it to the listing's 'bids' array in Firestore
  /// using arrayUnion (which prevents overwriting other collectors' bids).
  Future<void> _submitBid() async {
    // 1. Validate that the input is not empty
    if (_amountController.text.trim().isEmpty) {
      TopSnackBar.show(
        context,
        message: 'Please enter a bid amount',
        backgroundColor: Colors.red,
      );
      return;
    }

    // 2. Validate that the input is a valid positive number
    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      TopSnackBar.show(
        context,
        message: 'Please enter a valid positive amount',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // 3. Fetch the collector's current profile data to include in the bid
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final collectorName = userDoc.data()?['name'] ?? 'Anonymous Collector';
      final collectorRating = userDoc.data()?['rating'] ?? 0.0;

      // 4. Construct the new bid object
      final newBid = {
        'collectorUid': user.uid,
        'collectorName': collectorName,
        'amount': amount,
        'rating': collectorRating,
        'bidAt': DateTime.now(),
        'status': 'Pending',
      };

      // 5. Safely append the new bid to the listing's 'bids' array in Firestore
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .update({
            'bids': FieldValue.arrayUnion([newBid]),
          });

      if (!mounted) return;

      // 6. Show success message and navigate back twice (past the bottom sheet, back to Nearby Listings)
      TopSnackBar.show(
        context,
        message: 'Bid of ₱${amount.toStringAsFixed(2)} placed successfully! ✅',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context); // Closes the PlaceBidPage
      Navigator.pop(context); // Closes the Listing Bottom Sheet
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        message: 'Error placing bid: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Place a Bid screen
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Place a Bid', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Listing Summary Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Household: ${widget.householdName}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${widget.quantity}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Bid Input Section ---
            const Text(
              'Your Offer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (₱)',
                prefixIcon: const Icon(
                  Icons.attach_money,
                  color: Colors.orange,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'e.g., 150.00',
              ),
            ),
            const SizedBox(height: 32),

            // --- Submit Button ---
            PrimaryButton(
              text: 'SUBMIT BID',
              onPressed: _submitBid,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
