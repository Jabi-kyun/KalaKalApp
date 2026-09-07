import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // Added Import
import 'dart:convert'; // Added Import
import 'package:flutter_dotenv/flutter_dotenv.dart'; // To get API Key
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart';

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
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// NEW FUNCTION: SENDS PUSH NOTIFICATION VIA ONE SIGNAL REST API
  Future<void> _sendNotificationToHousehold(String householdUid) async {
    try {
      // 1. Get Household's OneSignal ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(householdUid)
          .get();

      final onesignalId = userDoc.data()?['onesignalId'];

      if (onesignalId != null) {
        // 2. Prepare the API Request
        final String appId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
        final String apiKey =
            dotenv.env['ONESIGNAL_REST_API_KEY'] ??
            ''; // Get this from OneSignal Dashboard

        final url = Uri.parse('https://onesignal.com/api/v1/notifications');

        final body = jsonEncode({
          "app_id": appId,
          "include_player_ids": [onesignalId],
          "headings": {"en": "New Bid Received! 🎉"},
          "contents": {
            "en": "A collector has bid on your ${widget.category} listing.",
          },
          "data": {"type": "new_bid", "listingId": widget.listingId},
        });

        // 3. Send the POST Request
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic $apiKey',
          },
          body: body,
        );

        if (response.statusCode == 200) {
          print("✅ Push Notification Sent via API!");
        } else {
          print("❌ Failed to send notification: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Error in notification logic: $e");
    }
  }

  Future<void> _submitBid() async {
    if (_amountController.text.trim().isEmpty) {
      TopSnackBar.show(
        context,
        message: 'Please enter a bid amount',
        backgroundColor: Colors.red,
      );
      return;
    }

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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final collectorName = userDoc.data()?['name'] ?? 'Anonymous Collector';
      final collectorRating = userDoc.data()?['rating'] ?? 0.0;

      final newBid = {
        'collectorUid': user.uid,
        'collectorName': collectorName,
        'amount': amount,
        'rating': collectorRating,
        'bidAt': DateTime.now(),
        'status': 'Pending',
      };

      // Get Listing Data to find Household UID
      final listingDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .get();
      final householdUid = listingDoc.data()?['householdUid'];

      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .update({
            'bids': FieldValue.arrayUnion([newBid]),
          });

      // TRIGGER NOTIFICATION IF WE HAVE THE HOUSEHOLD UID
      if (householdUid != null) {
        await _sendNotificationToHousehold(householdUid);
      }

      if (!mounted) return;

      TopSnackBar.show(
        context,
        message: 'Bid of ₱${amount.toStringAsFixed(2)} placed successfully!',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
      Navigator.pop(context);
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
