import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/star_rating.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class HouseholdHistoryPage extends StatefulWidget {
  const HouseholdHistoryPage({super.key});

  @override
  State<HouseholdHistoryPage> createState() => _HouseholdHistoryPageState();
}

class _HouseholdHistoryPageState extends State<HouseholdHistoryPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of the household's completed sales
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> history = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the sales history as soon as the page opens
    _fetchHistory();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING THE HOUSEHOLD'S COMPLETED SALES HISTORY.
  /// It queries the Firestore 'listings' collection, strictly filtering for
  /// documents where the 'householdUid' matches the current user AND the
  /// 'status' is 'Finished'. It then orders them by completion date (newest first).
  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Finished')
          .orderBy('completedAt', descending: true)
          .get();

      setState(() {
        history = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Attach document ID for reference
          return data;
        }).toList();
        isLoading = false; // Hide loading spinner
      });
    } catch (e) {
      debugPrint('❌ Error fetching household history: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Household's Sales History page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Sales History', showBackButton: true),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if the household hasn't completed any sales yet
          : history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No completed sales yet.',
              subtitle: 'Your finished transactions will appear here.',
            )
          // Show the scrollable list of completed sales with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];

                  // Format the Firestore Timestamp into a readable date string
                  final date = item['completedAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['completedAt'] as Timestamp).toDate())
                      : 'Unknown Date';

                  final collectorName =
                      item['acceptedBid']?['collectorName'] ?? 'Anonymous';
                  final collectorUid =
                      item['acceptedBid']?['collectorUid'] ?? '';
                  final amount = item['acceptedBid']?['amount'] ?? 0;
                  final householdRating =
                      item['householdRating'] ?? 0; // Check if already rated

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
                          // Top Row: Category and Status Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(
                                label: item['category'] ?? 'Unknown',
                                backgroundColor: Colors.green,
                              ),
                              const StatusChip(
                                label: 'COMPLETED',
                                backgroundColor: Colors.grey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Collector and Quantity Info
                          Text(
                            'Sold to: $collectorName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          // Final Earnings Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Final Amount',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '₱$amount',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // --- RATING SECTION ---
                          // Conditionally renders either the existing rating OR the "Rate Collector" button
                          if (householdRating > 0)
                            // If already rated, show the stars
                            Row(
                              children: [
                                const Text(
                                  'Your Rating: ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                StarRating(
                                  rating: householdRating.toDouble(),
                                  size: 16,
                                ),
                              ],
                            )
                          else
                            // If not yet rated, show the button to open the Rating Dialog
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: collectorUid.isEmpty
                                    ? null
                                    : () async {
                                        // Open the rating dialog and pass the collector's details
                                        await RatingDialog.show(
                                          context: context,
                                          targetUserId: collectorUid,
                                          targetUserName: collectorName,
                                          role: 'Collector',
                                          listingId: item['id'],
                                        );
                                        // Refresh the list to show the new rating immediately
                                        _fetchHistory();
                                      },
                                icon: const Icon(
                                  Icons.star_border,
                                  color: Colors.amber,
                                ),
                                label: const Text(
                                  'Rate Collector',
                                  style: TextStyle(color: Colors.amber),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.amber),
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),
                          // Date of completion
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
