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
      debugPrint('Error fetching collector history: $e');
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
                  final listingId = item['id'];
                  final date = item['completedAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['completedAt'] as Timestamp).toDate())
                      : 'Unknown Date';
                  final householdName =
                      item['householdName'] ?? 'Anonymous Household';
                  final amount = item['acceptedBid']?['amount'] ?? 0;
                  final collectorRating = (item['collectorRating'] ?? 0)
                      .toDouble();

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 16),
                      leading: Icon(
                        Icons.receipt_long,
                        color: Colors.green.shade700,
                      ),
                      title: Text(
                        householdName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(date),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱$amount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              const SizedBox(height: 8),
                              Text(
                                'Quantity: ${item['quantity']}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              if (collectorRating > 0) ...[
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      color: i < collectorRating
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              FutureBuilder<
                                QueryDocumentSnapshot<Map<String, dynamic>>?
                              >(
                                future: FirebaseFirestore.instance
                                    .collection('feedback')
                                    .where('listingId', isEqualTo: listingId)
                                    .limit(1)
                                    .get()
                                    .then(
                                      (snapshot) => snapshot.docs.isNotEmpty
                                          ? snapshot.docs.first
                                          : null,
                                    ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }

                                  final feedbackDoc = snapshot.data;
                                  if (feedbackDoc == null ||
                                      !feedbackDoc.exists) {
                                    return const Text(
                                      'No written feedback left.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey,
                                      ),
                                    );
                                  }

                                  final feedback =
                                      feedbackDoc.data()
                                          as Map<String, dynamic>;
                                  final comment =
                                      feedback['comment']?.toString() ?? '';

                                  return comment.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            comment,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
