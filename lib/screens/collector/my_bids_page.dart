import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications
import 'navigate_to_pickup_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class MyBidsPage extends StatefulWidget {
  const MyBidsPage({super.key});

  @override
  State<MyBidsPage> createState() => _MyBidsPageState();
}

class _MyBidsPageState extends State<MyBidsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of bids placed by this collector
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> myBids = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the collector's bids as soon as the page opens
    _fetchMyBids();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING AND ORGANIZING THE COLLECTOR'S BIDS.
  /// Since Firestore doesn't easily allow querying nested arrays (like bids.collectorUid),
  /// this function fetches all Active/Booked listings, loops through them locally in Dart
  /// to find where this specific collector placed a bid, extracts their bid details,
  /// and sorts the final list by date (newest first).
  Future<void> _fetchMyBids() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch all listings that are currently Active or Booked
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', whereIn: ['Active', 'Booked'])
          .get();

      List<Map<String, dynamic>> tempBids = [];

      // 2. Loop through listings to find this collector's bids
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final bidsList = (data['bids'] as List<dynamic>?);

        if (bidsList != null) {
          // Find the specific bid object belonging to this collector
          final myBid = bidsList.firstWhere(
            (bid) => (bid as Map)['collectorUid'] == user.uid,
            orElse: () => null,
          );

          if (myBid != null) {
            // Combine listing data with the collector's specific bid details
            tempBids.add({
              ...data,
              'myBidAmount': myBid['amount'],
              'myBidStatus': myBid['status'] ?? 'Pending',
              'bidAt': myBid['bidAt'],
            });
          }
        }
      }

      // 3. Sort the bids by date (newest first)
      tempBids.sort((a, b) {
        final dateA = a['bidAt'] is Timestamp
            ? (a['bidAt'] as Timestamp).toDate()
            : DateTime(2000);
        final dateB = b['bidAt'] is Timestamp
            ? (b['bidAt'] as Timestamp).toDate()
            : DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          myBids = tempBids;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching my bids: $e');
      if (mounted) {
        setState(() => isLoading = false);
        TopSnackBar.show(
          context,
          message: 'Failed to load bids: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// THESE CODES ARE FOR CONFIRMING A PICKUP AND COMPLETING THE TRANSACTION.
  /// It shows a confirmation dialog, updates the specific bid status to 'Finished'
  /// inside the bids array, changes the overall listing status to 'Finished',
  /// records the completion timestamp, and refreshes the UI.
  Future<void> _confirmPickup(String listingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Pickup?'),
        content: const Text(
          'Have you successfully collected the recyclables? '
          'This will mark the transaction as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final docRef = FirebaseFirestore.instance
            .collection('listings')
            .doc(listingId);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data()!;
          List<dynamic> bidsList = List<dynamic>.from(data['bids'] ?? []);

          // Update only THIS collector's bid status to 'Finished'
          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == user.uid) {
              bidsList[i]['status'] = 'Finished';
              break;
            }
          }

          // Save the updated bids array and mark the entire listing as Finished
          await docRef.update({
            'status': 'Finished',
            'completedAt': FieldValue.serverTimestamp(),
            'bids': bidsList,
          });

          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Pickup confirmed! Transaction completed. ✅',
              backgroundColor: Colors.green,
            );
            _fetchMyBids(); // Refresh the list to reflect the change
          }
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Error confirming pickup: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  /// HELPER FUNCTION TO ASSIGN COLORS BASED ON BID/LISTING STATUS.
  /// Returns a specific color for Pending, Accepted, Booked, Finished, or Rejected states.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'booked':
        return Colors.blue;
      case 'finished':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Collector's My Bids page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Bids', showBackButton: true),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if no bids have been placed yet
          : myBids.isEmpty
          ? const EmptyState(
              icon: Icons.gavel,
              title: 'No bids placed yet.',
              subtitle: 'Browse nearby listings and make your first offer!',
            )
          // Show the scrollable list of bids with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchMyBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myBids.length,
                itemBuilder: (context, index) {
                  final item = myBids[index];
                  final listingStatus = item['status'] ?? 'Active';
                  final bidStatus = item['myBidStatus'] ?? 'Pending';

                  // Format the bid timestamp into a readable date string
                  final date = item['bidAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['bidAt'] as Timestamp).toDate())
                      : 'Unknown Date';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Category and Listing Status Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(
                                label: item['category'] ?? 'Unknown',
                                backgroundColor: Colors.green,
                              ),
                              StatusChip(
                                label: listingStatus,
                                backgroundColor: _getStatusColor(listingStatus),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Household Info
                          Text(
                            item['householdName'] ?? 'Anonymous Household',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['description'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bid Details Box (Offer Amount & Current Status)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Offer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '₱${item['myBidAmount']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      bidStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(bidStatus),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ACTION BUTTONS: Only show if THIS collector won the bid and location exists
                          if (listingStatus == 'Booked' &&
                              item['myBidStatus'] == 'Accepted' &&
                              item['location'] != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final loc = item['location'];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NavigateToPickupPage(
                                        householdName:
                                            item['householdName'] ??
                                            'Household',
                                        address:
                                            item['address'] ??
                                            'No address provided',
                                        destinationLat: double.parse(
                                          loc['latitude'].toString(),
                                        ),
                                        destinationLng: double.parse(
                                          loc['longitude'].toString(),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'NAVIGATE TO PICKUP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmPickup(item['id']),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'CONFIRM PICKUP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // REJECTION MESSAGE: Shows politely if the bid was not accepted
                          if (item['myBidStatus'] == 'Rejected')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Center(
                                child: Text(
                                  'Your bid was not accepted.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),
                          // Date the bid was placed
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
