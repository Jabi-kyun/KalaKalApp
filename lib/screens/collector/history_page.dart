import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';

class CollectorHistoryPage extends StatefulWidget {
  const CollectorHistoryPage({super.key});

  @override
  State<CollectorHistoryPage> createState() => _CollectorHistoryPageState();
}

class _CollectorHistoryPageState extends State<CollectorHistoryPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .orderBy('completedAt', descending: true)
          .get();

      // Filter in Dart to find listings where this collector was the winner
      setState(() {
        history = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final acceptedBid = data['acceptedBid'] as Map<String, dynamic>?;
              return acceptedBid?['collectorUid'] == user.uid;
            })
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            })
            .toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching collector history: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Collection History',
        showBackButton: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No completed collections yet.',
              subtitle: 'Your finished pickups will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
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
                      0; // Check if already rated by household

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

                          // Show rating given by household
                          if (collectorRating > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Household Rating: ',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Icon(Icons.star, color: Colors.amber, size: 16),
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
