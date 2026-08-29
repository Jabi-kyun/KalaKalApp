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

// THIS CLASS DEFINES THE COLLECTOR HISTORY PAGE.
// IT ALLOWS COLLECTORS TO VIEW THEIR COMPLETED PICKUPS AND THE RATINGS RECEIVED.
class CollectorHistoryPage extends StatefulWidget {
  const CollectorHistoryPage({super.key});

  @override
  State<CollectorHistoryPage> createState() => _CollectorHistoryPageState();
}

class _CollectorHistoryPageState extends State<CollectorHistoryPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF THE COLLECTOR'S COMPLETED JOBS.
  bool isLoading = true;
  List<Map<String, dynamic>> history = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE COLLECTION HISTORY AS SOON AS THE PAGE OPENS.
    _fetchHistory();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES THE COLLECTOR'S COMPLETED HISTORY.
  /// SINCE FIRESTORE DOES NOT EASILY ALLOW QUERYING NESTED MAP FIELDS (LIKE ACCEPTEDBID.COLLECTORUID),
  /// THIS FUNCTION FETCHES ALL 'FINISHED' LISTINGS AND FILTERS THEM LOCALLY IN DART
  /// TO ONLY SHOW THE JOBS WHERE THIS SPECIFIC COLLECTOR WON THE BID.
  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. FETCH ALL LISTINGS THAT HAVE BEEN MARKED AS 'FINISHED'.
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .orderBy('completedAt', descending: true)
          .get();

      // 2. FILTER THE RESULTS LOCALLY TO MATCH THE CURRENT COLLECTOR'S UID.
      setState(() {
        history = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final acceptedBid = data['acceptedBid'] as Map<String, dynamic>?;
              // ONLY KEEP THE LISTING IF THIS COLLECTOR WAS THE ONE WHO WON THE BID.
              return acceptedBid?['collectorUid'] == user.uid;
            })
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // ATTACH DOCUMENT ID FOR REFERENCE.
              return data;
            })
            .toList();
        isLoading = false; // HIDE LOADING SPINNER.
      });
    } catch (e) {
      debugPrint('Error fetching collector history: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE COLLECTOR'S HISTORY PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Collection History',
        showBackButton: true,
      ),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA.
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF THE COLLECTOR HASN'T FINISHED ANY JOBS YET.
          : history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No completed collections yet.',
              subtitle: 'Your finished pickups will appear here.',
            )
          // SHOW THE SCROLLABLE LIST OF COMPLETED JOBS WITH PULL-TO-REFRESH.
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];

                  // FORMAT THE FIRESTORE TIMESTAMP INTO A READABLE DATE STRING.
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
                      0; // RATING GIVEN BY THE HOUSEHOLD.

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
                          // TOP ROW: CATEGORY AND STATUS CHIPS.
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

                          // HOUSEHOLD INFO.
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

                          // FINAL EARNINGS BOX.
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
                                  'P$amount',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // HOUSEHOLD RATING (ONLY SHOWS IF THE HOUSEHOLD ACTUALLY RATED THE COLLECTOR).
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
                          // DATE OF COMPLETION.
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
