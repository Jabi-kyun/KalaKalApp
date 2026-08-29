import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE PLACE BID PAGE FOR COLLECTORS.
// IT ALLOWS COLLECTORS TO VIEW A LISTING SUMMARY AND SUBMIT A FINANCIAL OFFER.
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
  // ==========================================================================

  // THESE HOLD THE TEXT INPUT FOR THE BID AMOUNT AND THE LOADING STATE.
  final _amountController = TextEditingController();
  bool _isLoading = false;

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void dispose() {
    // CLEANS UP MEMORY BY DISPOSING THE TEXT CONTROLLER WHEN THE PAGE IS CLOSED.
    _amountController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION HANDLES SUBMITTING A BID TO A LISTING.
  /// IT VALIDATES THAT THE ENTERED AMOUNT IS A VALID POSITIVE NUMBER, FETCHES THE
  /// COLLECTOR'S CURRENT NAME AND RATING FROM THEIR USER PROFILE, CONSTRUCTS A NEW
  /// BID OBJECT, AND SAFELY APPENDS IT TO THE LISTING'S 'BIDS' ARRAY IN FIRESTORE
  /// USING ARRAYUNION (WHICH PREVENTS OVERWRITING OTHER COLLECTORS' BIDS).
  Future<void> _submitBid() async {
    // 1. VALIDATE THAT THE INPUT IS NOT EMPTY.
    if (_amountController.text.trim().isEmpty) {
      TopSnackBar.show(
        context,
        message: 'Please enter a bid amount',
        backgroundColor: Colors.red,
      );
      return;
    }

    // 2. VALIDATE THAT THE INPUT IS A VALID POSITIVE NUMBER.
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

      // 3. FETCH THE COLLECTOR'S CURRENT PROFILE DATA TO INCLUDE IN THE BID.
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final collectorName = userDoc.data()?['name'] ?? 'Anonymous Collector';
      final collectorRating = userDoc.data()?['rating'] ?? 0.0;

      // 4. CONSTRUCT THE NEW BID OBJECT.
      final newBid = {
        'collectorUid': user.uid,
        'collectorName': collectorName,
        'amount': amount,
        'rating': collectorRating,
        'bidAt': DateTime.now(),
        'status': 'Pending',
      };

      // 5. SAFELY APPEND THE NEW BID TO THE LISTING'S 'BIDS' ARRAY IN FIRESTORE.
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .update({
            'bids': FieldValue.arrayUnion([newBid]),
          });

      if (!mounted) return;

      // 6. SHOW SUCCESS MESSAGE AND NAVIGATE BACK TWICE (PAST THE BOTTOM SHEET, BACK TO NEARBY LISTINGS).
      TopSnackBar.show(
        context,
        message: 'Bid of P${amount.toStringAsFixed(2)} placed successfully!',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context); // CLOSES THE PLACEBIDPAGE
      Navigator.pop(context); // CLOSES THE LISTING BOTTOM SHEET
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
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE PLACE A BID SCREEN.
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
            // --- LISTING SUMMARY CARD ---
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

            // --- BID INPUT SECTION ---
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
                labelText: 'Amount (P)',
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

            // --- SUBMIT BUTTON ---
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
