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

class MyActiveListingsPage extends StatefulWidget {
  const MyActiveListingsPage({super.key});

  @override
  State<MyActiveListingsPage> createState() => _MyActiveListingsPageState();
}

class _MyActiveListingsPageState extends State<MyActiveListingsPage> {
  
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> activeListings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _fetchActiveListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING THE HOUSEHOLD'S ACTIVE & PENDING LISTINGS.
  /// ✅ UPDATED: Now includes 'Pending Confirmation' status so households 
  /// can see listings that need their final approval.
  Future<void> _fetchActiveListings() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ UPDATED: Fetch Active AND Pending Confirmation listings
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
      debugPrint(' Error fetching active listings: $e');
      setState(() => isLoading = false);
    }
  }

  /// THESE CODES ARE FOR THE HOUSEHOLD TO CONFIRM TRANSACTION COMPLETION.
  /// This is the SECOND step of the two-party confirmation flow.
  /// It changes the status from 'Pending Confirmation' to 'Finished'.
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('listings').doc(listingId).update({
          'status': 'Finished',
          'completedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          TopSnackBar.show(context, message: 'Transaction completed successfully! ✅', backgroundColor: Colors.green);
          _fetchActiveListings(); // Refresh to remove it from active list
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(context, message: 'Error confirming completion: $e', backgroundColor: Colors.red);
        }
      }
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Received Bids', showBackButton: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : activeListings.isEmpty
          ? const EmptyState(icon: Icons.monetization_on_outlined, title: 'No active listings.', subtitle: 'Post a scrap to start receiving bids!')
          : RefreshIndicator(
              onRefresh: _fetchActiveListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeListings.length,
                itemBuilder: (context, index) {
                  final item = activeListings[index];
                  final status = item['status'] ?? 'Active';
                  final isPendingConfirmation = status == 'Pending Confirmation';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPendingConfirmation ? Colors.purple.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPendingConfirmation ? Icons.hourglass_empty : Icons.recycling,
                          color: isPendingConfirmation ? Colors.purple.shade700 : Colors.green.shade700,
                        ),
                      ),
                      title: Text(
                        item['category'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['quantity']} • ${item['description']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (isPendingConfirmation)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '⏳ Collector confirmed pickup. Awaiting your approval.',
                                style: TextStyle(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                      trailing: isPendingConfirmation
                          ? ElevatedButton.icon(
                              onPressed: () => _confirmCompletion(item['id']),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: isPendingConfirmation ? null : () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ReceivedBidsPage(
                          listingId: item['id'],
                          listingCategory: item['category'] ?? 'Unknown',
                          listingQuantity: item['quantity'] ?? '',
                        )));
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}