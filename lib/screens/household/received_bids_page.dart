import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE RECEIVED BIDS PAGE FOR HOUSEHOLDS.
// IT ALLOWS USERS TO VIEW, SORT, AND ACCEPT BIDS PLACED BY COLLECTORS.
class ReceivedBidsPage extends StatefulWidget {
  final String listingId;
  final String listingCategory;
  final String listingQuantity;

  const ReceivedBidsPage({
    super.key,
    required this.listingId,
    required this.listingCategory,
    required this.listingQuantity,
  });

  @override
  State<ReceivedBidsPage> createState() => _ReceivedBidsPageState();
}

class _ReceivedBidsPageState extends State<ReceivedBidsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> bids = [];
  String listingStatus = 'Active';

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _fetchBids();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES BIDS AND CALCULATES THE COLLECTOR'S REPUTATION.
  /// IT RETRIEVES THE LISTING'S BIDS AND DYNAMICALLY CALCULATES EACH COLLECTOR'S
  /// TRUE AVERAGE RATING BY CHECKING ALL HISTORICALLY FINISHED TRANSACTIONS.
  Future<void> _fetchBids() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listingId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        listingStatus = data?['status'] ?? 'Active';

        if (listingStatus != 'Active' &&
            listingStatus != 'Pending Confirmation') {
          setState(() => isLoading = false);
          return;
        }

        final rawBids = (data?['bids'] as List<dynamic>?) ?? [];
        bids = rawBids.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        // STEP 1: FETCH ALL FINISHED TRANSACTIONS TO BUILD A REPUTATION MAP.
        // THIS ENSURES WE FIND RATINGS EVEN ON OLDER TRANSACTIONS THAT LACK 'WINNERUID'.
        final allFinishedSnapshot = await FirebaseFirestore.instance
            .collection('listings')
            .where('status', isEqualTo: 'Finished')
            .get();

        // MAP TO STORE { COLLECTORUID: { 'TOTAL': DOUBLE, 'COUNT': INT } }
        Map<String, Map<String, dynamic>> collectorStats = {};

        for (var finishedDoc in allFinishedSnapshot.docs) {
          final finishedData = finishedDoc.data();
          final acceptedBid =
              finishedData['acceptedBid'] as Map<String, dynamic>?;
          final rating = finishedData['collectorRating'] ?? 0;

          // ONLY COUNT IF THERE IS A VALID COLLECTOR AND A RATING GREATER THAN 0
          if (acceptedBid != null &&
              acceptedBid['collectorUid'] != null &&
              rating > 0) {
            String uid = acceptedBid['collectorUid'];

            if (!collectorStats.containsKey(uid)) {
              collectorStats[uid] = {'total': 0.0, 'count': 0};
            }

            collectorStats[uid]!['total'] =
                (collectorStats[uid]!['total'] as double) + rating;
            collectorStats[uid]!['count'] =
                (collectorStats[uid]!['count'] as int) + 1;
          }
        }

        // STEP 2: ATTACH THE CALCULATED AVERAGE TO EACH BID.
        for (var bid in bids) {
          String uid = bid['collectorUid'];

          if (collectorStats.containsKey(uid)) {
            double total = collectorStats[uid]!['total'];
            int count = collectorStats[uid]!['count'];
            bid['averageCollectorRating'] = (total / count).toStringAsFixed(1);
          } else {
            bid['averageCollectorRating'] = null; // TRULY A NEW COLLECTOR
          }
        }

        // SORT BIDS BY AMOUNT IN DESCENDING ORDER (HIGHEST BID FIRST).
        bids.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));

        setState(() => isLoading = false);
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching bids: $e');
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

  /// THIS FUNCTION HANDLES ACCEPTING A BID AND LOCKING THE TRANSACTION.
  /// IT UPDATES THE WINNING BID STATUS TO 'ACCEPTED', REJECTS ALL OTHERS,
  /// AND CHANGES THE LISTING STATUS TO 'BOOKED'.
  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Bid?'),
        content: Text(
          'Accept P${bid['amount']} from ${bid['collectorName']}?\n\n'
          'This will lock the transaction and share your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listingId);
        final doc = await docRef.get();

        if (doc.exists) {
          final data = doc.data()!;
          List<dynamic> bidsList = List<dynamic>.from(data['bids'] ?? []);
          final winningCollectorUid = bid['collectorUid'];

          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == winningCollectorUid) {
              bidsList[i]['status'] = 'Accepted';
            } else {
              bidsList[i]['status'] = 'Rejected';
            }
          }

          await docRef.update({
            'status': 'Booked',
            'acceptedBid': bid,
            'winnerUid':
                winningCollectorUid, // SAVED FOR FUTURE SCALABLE QUERIES
            'bids': bidsList,
            'bookedAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Bid accepted successfully!',
              backgroundColor: Colors.green,
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Error accepting bid: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // EDGE CASE: DISPLAY STATIC SCREEN IF LISTING IS ALREADY PROCESSED (BOOKED OR FINISHED)
    if (!isLoading &&
        listingStatus != 'Active' &&
        listingStatus != 'Pending Confirmation') {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F7F3),
        appBar: AppBar(
          backgroundColor: Colors.green,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Listing Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  listingStatus == 'Finished'
                      ? Icons.check_circle
                      : Icons.handshake,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                Text(
                  'This listing is already $listingStatus.',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  listingStatus == 'Finished'
                      ? 'The transaction has been successfully completed.'
                      : 'A collector has accepted your listing and is on their way.',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // MAIN UI: THE ACTIVE BIDDING INTERFACE
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Received Bids',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${widget.listingCategory} • ${widget.listingQuantity}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : bids.isEmpty
          ? const EmptyState(
              icon: Icons.monetization_on_outlined,
              title: 'No bids yet.',
              subtitle: 'Collectors are reviewing your listing...',
            )
          : RefreshIndicator(
              onRefresh: _fetchBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  final isHighest = index == 0;

                  // EXTRACT THE DYNAMICALLY CALCULATED AVERAGE RATING
                  final avgRating = bid['averageCollectorRating'];

                  return Card(
                    elevation: isHighest ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isHighest ? const Color(0xFFE8F5E9) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green,
                                      radius: 18,
                                      child: Text(
                                        (bid['collectorName'] ?? '?')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bid['collectorName'] ??
                                                'Anonymous Collector',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),

                                          // DISPLAY SINGLE TRANSACTION RATING IF AVAILABLE
                                          if ((bid['rating'] ?? 0) > 0)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 14,
                                                ),
                                                Text(
                                                  '${bid['rating']}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),

                                          // DISPLAY OVERALL DYNAMIC REPUTATION SCORE
                                          if (avgRating != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$avgRating / 5.0',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.amber.shade800,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '(Overall Reputation)',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'New Collector',
                                              style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'P${bid['amount']}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isHighest
                                      ? Colors.green
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isHighest)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'HIGHEST BID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _acceptBid(bid),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  'ACCEPT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
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
