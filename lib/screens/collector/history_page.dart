import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class CollectorHistoryPage extends StatefulWidget {
  const CollectorHistoryPage({super.key});

  @override
  State<CollectorHistoryPage> createState() => _CollectorHistoryPageState();
}

class _CollectorHistoryPageState extends State<CollectorHistoryPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of the collector's completed jobs
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> history = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the collection history as soon as the page opens
    _fetchHistory();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING THE COLLECTOR'S COMPLETED HISTORY.
  /// Since Firestore doesn't easily allow querying nested map fields (like acceptedBid.collectorUid),
  /// this function fetches all 'Finished' listings and filters them locally in Dart
  /// to only show the jobs where this specific collector won the bid.
  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch all listings that have been marked as 'Finished'
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .orderBy('completedAt', descending: true)
          .get();

      // 2. Filter the results locally to match the current collector's UID
      setState(() {
        history = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final acceptedBid = data['acceptedBid'] as Map<String, dynamic>?;
              // Only keep the listing if this collector was the one who won the bid
              return acceptedBid?['collectorUid'] == user.uid;
            })
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // Attach document ID for reference
              return data;
            })
            .toList();
        isLoading = false; // Hide loading spinner
      });
    } catch (e) {
      debugPrint('❌ Error fetching collector history: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Collector's History page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Collection History',
        showBackButton: true,
      ),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if the collector hasn't finished any jobs yet
          : history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No completed collections yet.',
              subtitle: 'Your finished pickups will appear here.',
            )
          // Show the scrollable list of completed jobs with pull-to-refresh
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

                  final householdName =
                      item['householdName'] ?? 'Anonymous Household';
                  final amount = item['acceptedBid']?['amount'] ?? 0;
                  final collectorRating =
                      item['collectorRating'] ??
                      0; // Rating given by the household

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

                          // Household Info
                          Text(
                            'Collected from: $householdName',
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

                          // Household Rating (Only shows if the household actually rated the collector)
                          if (collectorRating > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Household Rating: ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                Text(
                                  '$collectorRating / 5',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],

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
