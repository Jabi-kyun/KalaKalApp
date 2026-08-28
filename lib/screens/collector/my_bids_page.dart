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

class MyBidsPage extends StatefulWidget {
  const MyBidsPage({super.key});

  @override
  State<MyBidsPage> createState() => _MyBidsPageState();
}

class _MyBidsPageState extends State<MyBidsPage> {
  
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> myBids = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _fetchMyBids();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING AND ORGANIZING THE COLLECTOR'S BIDS.
  /// Updated to include 'Pending Confirmation' status so collectors can see 
  /// transactions waiting for household approval.
  Future<void> _fetchMyBids() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ UPDATED: Fetch Active, Booked, AND Pending Confirmation listings
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', whereIn: ['Active', 'Booked', 'Pending Confirmation'])
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

      tempBids.sort((a, b) {
        final dateA = a['bidAt'] is Timestamp ? (a['bidAt'] as Timestamp).toDate() : DateTime(2000);
        final dateB = b['bidAt'] is Timestamp ? (b['bidAt'] as Timestamp).toDate() : DateTime(2000);
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
        TopSnackBar.show(context, message: 'Failed to load bids: $e', backgroundColor: Colors.red);
      }
    }
  }

  /// THESE CODES ARE FOR CONFIRMING A PICKUP (COLLECTOR SIDE).
  /// ✅ UPDATED: Now sets status to 'Pending Confirmation' instead of 'Finished'.
  /// This ensures the transaction isn't closed until the Household also confirms.
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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

        final docRef = FirebaseFirestore.instance.collection('listings').doc(listingId);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data()!;
          List<dynamic> bidsList = List<dynamic>.from(data['bids'] ?? []);

          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == user.uid) {
              bidsList[i]['status'] = 'Accepted'; // Keep bid status as accepted
              break;
            }
          }

          // ✅ CRITICAL CHANGE: Set main status to 'Pending Confirmation'
          await docRef.update({
            'status': 'Pending Confirmation',
            'pendingConfirmationAt': FieldValue.serverTimestamp(),
            'bids': bidsList,
          });

          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Pickup confirmed! Waiting for household confirmation. ⏳',
              backgroundColor: Colors.orange,
            );
            _fetchMyBids();
          }
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(context, message: 'Error confirming pickup: $e', backgroundColor: Colors.red);
        }
      }
    }
  }

  /// HELPER FUNCTION TO ASSIGN COLORS BASED ON BID/LISTING STATUS.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':             return Colors.orange;
      case 'accepted':            return Colors.green;
      case 'booked':              return Colors.blue;
      case 'pending confirmation': return Colors.purple; // ✅ New color for intermediate state
      case 'finished':            return Colors.grey;
      case 'rejected':            return Colors.red;
      default:                    return Colors.grey;
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Bids', showBackButton: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : myBids.isEmpty
          ? const EmptyState(icon: Icons.gavel, title: 'No bids placed yet.', subtitle: 'Browse nearby listings and make your first offer!')
          : RefreshIndicator(
              onRefresh: _fetchMyBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myBids.length,
                itemBuilder: (context, index) {
                  final item = myBids[index];
                  final listingStatus = item['status'] ?? 'Active';
                  final bidStatus = item['myBidStatus'] ?? 'Pending';
                  final date = item['bidAt'] != null ? DateFormat('MMM dd, yyyy').format((item['bidAt'] as Timestamp).toDate()) : 'Unknown Date';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(label: item['category'] ?? 'Unknown', backgroundColor: Colors.green),
                              StatusChip(label: listingStatus, backgroundColor: _getStatusColor(listingStatus)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(item['householdName'] ?? 'Anonymous Household', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text('Quantity: ${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(item['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 16),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Your Offer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('₱${item['myBidAmount']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(bidStatus.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _getStatusColor(bidStatus))),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ✅ UPDATED CONDITION: Show buttons for Booked OR Pending Confirmation
                          if ((listingStatus == 'Booked' || listingStatus == 'Pending Confirmation') &&
                              item['myBidStatus'] == 'Accepted' &&
                              item['location'] != null) ...[
                            
                            // Only show Navigate button if still Booked (not yet confirmed by collector)
                            if (listingStatus == 'Booked')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final loc = item['location'];
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => NavigateToPickupPage(
                                      householdName: item['householdName'] ?? 'Household',
                                      address: item['address'] ?? 'No address provided',
                                      destinationLat: double.parse(loc['latitude'].toString()),
                                      destinationLng: double.parse(loc['longitude'].toString()),
                                    )));
                                  },
                                  icon: const Icon(Icons.navigation, color: Colors.white),
                                  label: const Text('NAVIGATE TO PICKUP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // Show Confirm Pickup button for BOTH Booked and Pending Confirmation states
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmPickup(item['id']),
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                                label: Text(
                                  listingStatus == 'Pending Confirmation' ? 'WAITING FOR HOUSEHOLD...' : 'CONFIRM PICKUP',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: listingStatus == 'Pending Confirmation' ? Colors.purple : Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],

                          if (item['myBidStatus'] == 'Rejected')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                              child: const Center(child: Text('Your bid was not accepted.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            ),

                          const SizedBox(height: 8),
                          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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