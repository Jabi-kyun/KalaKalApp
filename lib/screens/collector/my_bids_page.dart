import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';
import 'navigate_to_pickup_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE MY BIDS PAGE FOR COLLECTORS.
// IT ALLOWS COLLECTORS TO VIEW THEIR PLACED BIDS, TRACK THEIR STATUS,
// AND CONFIRM PICKUPS FOR ACCEPTED BIDS.
class MyBidsPage extends StatefulWidget {
  const MyBidsPage({super.key});

  @override
  State<MyBidsPage> createState() => _MyBidsPageState();
}

class _MyBidsPageState extends State<MyBidsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF THE COLLECTOR'S BIDS.
  bool isLoading = true;
  List<Map<String, dynamic>> myBids = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE COLLECTOR'S BIDS AS SOON AS THE PAGE OPENS.
    _fetchMyBids();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES AND ORGANIZES THE COLLECTOR'S BIDS.
  /// UPDATED TO INCLUDE 'PENDING CONFIRMATION' STATUS SO COLLECTORS CAN SEE
  /// TRANSACTIONS WAITING FOR HOUSEHOLD APPROVAL.
  Future<void> _fetchMyBids() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // FETCH ACTIVE, BOOKED, AND PENDING CONFIRMATION LISTINGS.
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where(
            'status',
            whereIn: ['Active', 'Booked', 'Pending Confirmation'],
          )
          .get();

      List<Map<String, dynamic>> tempBids = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final bidsList = (data['bids'] as List<dynamic>?);

        if (bidsList != null) {
          final myBid = bidsList.firstWhere(
            (bid) => (bid as Map)['collectorUid'] == user.uid,
            orElse: () => null,
          );

          if (myBid != null) {
            tempBids.add({
              ...data,
              'myBidAmount': myBid['amount'],
              'myBidStatus': myBid['status'] ?? 'Pending',
              'bidAt': myBid['bidAt'],
            });
          }
        }
      }

      // SORT BIDS BY DATE IN DESCENDING ORDER (NEWEST FIRST).
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
      debugPrint('Error fetching my bids: $e');
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

  /// THIS FUNCTION HANDLES CONFIRMING A PICKUP ON THE COLLECTOR SIDE.
  /// UPDATED: NOW SETS STATUS TO 'PENDING CONFIRMATION' INSTEAD OF 'FINISHED'.
  /// THIS ENSURES THE TRANSACTION IS NOT CLOSED UNTIL THE HOUSEHOLD ALSO CONFIRMS.
  Future<void> _confirmPickup(String listingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Pickup?'),
        content: const Text(
          'Have you successfully collected the recyclables? '
          'The household will be notified to confirm completion.',
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

          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == user.uid) {
              bidsList[i]['status'] = 'Accepted'; // KEEP BID STATUS AS ACCEPTED
              break;
            }
          }

          // CRITICAL CHANGE: SET MAIN STATUS TO 'PENDING CONFIRMATION'.
          await docRef.update({
            'status': 'Pending Confirmation',
            'pendingConfirmationAt': FieldValue.serverTimestamp(),
            'bids': bidsList,
          });

          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Pickup confirmed! Waiting for household confirmation.',
              backgroundColor: Colors.orange,
            );
            _fetchMyBids();
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

  /// HELPER FUNCTION TO ASSIGN COLORS BASED ON BID OR LISTING STATUS.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'booked':
        return Colors.blue;
      case 'pending confirmation':
        return Colors.purple; // NEW COLOR FOR INTERMEDIATE STATE
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
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE COLLECTOR'S MY BIDS PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Bids', showBackButton: true),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA.
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF NO BIDS HAVE BEEN PLACED YET.
          : myBids.isEmpty
          ? const EmptyState(
              icon: Icons.gavel,
              title: 'No bids placed yet.',
              subtitle: 'Browse nearby listings and make your first offer!',
            )
          // SHOW THE SCROLLABLE LIST OF BIDS WITH PULL-TO-REFRESH.
          : RefreshIndicator(
              onRefresh: _fetchMyBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myBids.length,
                itemBuilder: (context, index) {
                  final item = myBids[index];
                  final listingStatus = item['status'] ?? 'Active';
                  final bidStatus = item['myBidStatus'] ?? 'Pending';
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
                          // TOP ROW: CATEGORY AND LISTING STATUS CHIPS.
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

                          // HOUSEHOLD AND LISTING DETAILS.
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

                          // BID DETAILS BOX (OFFER AMOUNT AND CURRENT STATUS).
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
                                      'P${item['myBidAmount']}',
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

                          // UPDATED CONDITION: SHOW BUTTONS FOR BOOKED OR PENDING CONFIRMATION.
                          if ((listingStatus == 'Booked' ||
                                  listingStatus == 'Pending Confirmation') &&
                              item['myBidStatus'] == 'Accepted' &&
                              item['location'] != null) ...[
                            // ONLY SHOW NAVIGATE BUTTON IF STILL BOOKED (NOT YET CONFIRMED BY COLLECTOR).
                            if (listingStatus == 'Booked')
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

                            // SHOW CONFIRM PICKUP BUTTON FOR BOTH BOOKED AND PENDING CONFIRMATION STATES.
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmPickup(item['id']),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  listingStatus == 'Pending Confirmation'
                                      ? 'WAITING FOR HOUSEHOLD...'
                                      : 'CONFIRM PICKUP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      listingStatus == 'Pending Confirmation'
                                      ? Colors.purple
                                      : Colors.blue,
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

                          // REJECTION MESSAGE: SHOWS POLITELY IF THE BID WAS NOT ACCEPTED.
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
                          // DATE THE BID WAS PLACED.
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
