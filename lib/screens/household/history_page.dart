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

// THIS CLASS DEFINES THE HOUSEHOLD HISTORY PAGE.
// IT ALLOWS USERS TO VIEW THEIR COMPLETED SALES AND RATE THE COLLECTORS.
class HouseholdHistoryPage extends StatefulWidget {
  const HouseholdHistoryPage({super.key});

  @override
  State<HouseholdHistoryPage> createState() => _HouseholdHistoryPageState();
}

class _HouseholdHistoryPageState extends State<HouseholdHistoryPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF THE HOUSEHOLD'S COMPLETED SALES.
  bool isLoading = true;
  List<Map<String, dynamic>> history = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE SALES HISTORY AS SOON AS THE PAGE OPENS.
    _fetchHistory();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES THE HOUSEHOLD'S COMPLETED SALES HISTORY.
  /// IT QUERIES THE FIRESTORE 'LISTINGS' COLLECTION, STRICTLY FILTERING FOR
  /// DOCUMENTS WHERE THE 'HOUSEHOLDUID' MATCHES THE CURRENT USER AND THE
  /// 'STATUS' IS 'FINISHED'. IT THEN ORDERS THEM BY COMPLETION DATE (NEWEST FIRST).
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
          data['id'] = doc.id; // ATTACH DOCUMENT ID FOR REFERENCE
          return data;
        }).toList();
        isLoading = false; // HIDE LOADING SPINNER
      });
    } catch (e) {
      debugPrint('Error fetching household history: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE HOUSEHOLD'S SALES HISTORY PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Sales History', showBackButton: true),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF THE HOUSEHOLD HASN'T COMPLETED ANY SALES YET
          : history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No completed sales yet.',
              subtitle: 'Your finished transactions will appear here.',
            )
          // SHOW THE SCROLLABLE LIST OF COMPLETED SALES WITH PULL-TO-REFRESH
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];

                  // FORMAT THE FIRESTORE TIMESTAMP INTO A READABLE DATE STRING
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
                      item['householdRating'] ?? 0; // CHECK IF ALREADY RATED

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
                          // TOP ROW: CATEGORY AND STATUS CHIPS
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

                          // COLLECTOR AND QUANTITY INFO
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

                          // FINAL EARNINGS BOX
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
                          const SizedBox(height: 12),

                          // RATING SECTION: CONDITIONALLY RENDERS EITHER THE EXISTING RATING OR THE "RATE COLLECTOR" BUTTON
                          if (householdRating > 0)
                            // IF ALREADY RATED, SHOW THE STARS
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
                            // IF NOT YET RATED, SHOW THE BUTTON TO OPEN THE RATING DIALOG
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: collectorUid.isEmpty
                                    ? null
                                    : () async {
                                        // OPEN THE RATING DIALOG AND PASS THE COLLECTOR'S DETAILS
                                        await RatingDialog.show(
                                          context: context,
                                          targetUserId: collectorUid,
                                          targetUserName: collectorName,
                                          role: 'Collector',
                                          listingId: item['id'],
                                        );
                                        // REFRESH THE LIST TO SHOW THE NEW RATING IMMEDIATELY
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
                          // DATE OF COMPLETION
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
