import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';
import 'received_bids_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE MY ACTIVE LISTINGS PAGE FOR HOUSEHOLDS.
// IT ALLOWS USERS TO VIEW THEIR ACTIVE LISTINGS AND CONFIRM COMPLETED PICKUPS.
class MyActiveListingsPage extends StatefulWidget {
  const MyActiveListingsPage({super.key});

  @override
  State<MyActiveListingsPage> createState() => _MyActiveListingsPageState();
}

class _MyActiveListingsPageState extends State<MyActiveListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF THE HOUSEHOLD'S ACTIVE LISTINGS.
  bool isLoading = true;
  List<Map<String, dynamic>> activeListings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH ACTIVE LISTINGS AS SOON AS THE PAGE OPENS.
    _fetchActiveListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES THE HOUSEHOLD'S ACTIVE AND PENDING LISTINGS.
  /// UPDATED: NOW INCLUDES 'PENDING CONFIRMATION' STATUS SO HOUSEHOLDS
  /// CAN SEE LISTINGS THAT NEED THEIR FINAL APPROVAL.
  Future<void> _fetchActiveListings() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // FETCH ACTIVE AND PENDING CONFIRMATION LISTINGS
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .where('status', whereIn: ['Active', 'Pending Confirmation'])
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        activeListings = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching active listings: $e');
      setState(() => isLoading = false);
    }
  }

  /// THIS FUNCTION IS FOR THE HOUSEHOLD TO CONFIRM TRANSACTION COMPLETION.
  /// THIS IS THE SECOND STEP OF THE TWO-PARTY CONFIRMATION FLOW.
  /// IT CHANGES THE STATUS FROM 'PENDING CONFIRMATION' TO 'FINISHED'.
  Future<void> _confirmCompletion(String listingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Completion?'),
        content: const Text(
          'Has the collector successfully picked up your recyclables? '
          'This will permanently close the transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Yes, Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(listingId)
            .update({
              'status': 'Finished',
              'completedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Transaction completed successfully!',
            backgroundColor: Colors.green,
          );
          _fetchActiveListings(); // REFRESH TO REMOVE IT FROM ACTIVE LIST
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Error confirming completion: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE HOUSEHOLD'S ACTIVE LISTINGS PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Received Bids', showBackButton: true),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF THE HOUSEHOLD HAS NO ACTIVE LISTINGS
          : activeListings.isEmpty
          ? const EmptyState(
              icon: Icons.monetization_on_outlined,
              title: 'No active listings.',
              subtitle: 'Post a scrap to start receiving bids!',
            )
          // SHOW THE SCROLLABLE LIST OF ACTIVE LISTINGS WITH PULL-TO-REFRESH
          : RefreshIndicator(
              onRefresh: _fetchActiveListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeListings.length,
                itemBuilder: (context, index) {
                  final item = activeListings[index];
                  final status = item['status'] ?? 'Active';
                  final isPendingConfirmation =
                      status == 'Pending Confirmation';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPendingConfirmation
                              ? Colors.purple.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPendingConfirmation
                              ? Icons.hourglass_empty
                              : Icons.recycling,
                          color: isPendingConfirmation
                              ? Colors.purple.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      title: Text(
                        item['category'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['quantity']} • ${item['description']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isPendingConfirmation)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Collector confirmed pickup. Awaiting your approval.',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: isPendingConfirmation
                          ? ElevatedButton.icon(
                              onPressed: () => _confirmCompletion(item['id']),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text(
                                'CONFIRM',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                      onTap: isPendingConfirmation
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceivedBidsPage(
                                    listingId: item['id'],
                                    listingCategory:
                                        item['category'] ?? 'Unknown',
                                    listingQuantity: item['quantity'] ?? '',
                                  ),
                                ),
                              );
                            },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
