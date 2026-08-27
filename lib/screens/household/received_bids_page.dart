import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// WIDGET CLASS
// ============================================================================

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
  // These hold the loading state, the list of bids, and the current listing status
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
    // Automatically fetch the bids for this specific listing when the page opens
    _fetchBids();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING AND SORTING THE BIDS FOR A LISTING.
  /// It fetches the specific listing document, checks if it's still 'Active',
  /// extracts the 'bids' array, and sorts it in descending order by amount
  /// so the highest bid always appears at the top (index 0).
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

        // If the listing is no longer Active (e.g., Booked or Finished), stop fetching bids
        if (listingStatus != 'Active') {
          setState(() => isLoading = false);
          return;
        }

        final rawBids = (data?['bids'] as List<dynamic>?) ?? [];

        setState(() {
          bids = rawBids
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          // Sort bids by amount in descending order (Highest bid first)
          bids.sort(
            (a, b) => (b['amount'] as num).compareTo(a['amount'] as num),
          );
          isLoading = false;
        });
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching bids: $e');
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

  /// THESE CODES ARE FOR ACCEPTING A BID AND LOCKING THE TRANSACTION.
  /// This is a critical function: it loops through ALL bids in the listing,
  /// explicitly marks the chosen collector's bid as 'Accepted', and marks
  /// all other competing bids as 'Rejected'. It then updates the main listing
  /// status to 'Booked' to prevent any further changes or bids.
  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Bid?'),
        content: Text(
          'Accept ₱${bid['amount']} from ${bid['collectorName']}?\n\n'
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

          // ✅ CRITICAL FIX: Loop through all bids to explicitly set winner and losers
          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == winningCollectorUid) {
              bidsList[i]['status'] = 'Accepted'; // Winner
            } else {
              bidsList[i]['status'] = 'Rejected'; // Losers
            }
          }

          // Update the listing with the new bids array, status, and accepted bid details
          await docRef.update({
            'status': 'Booked',
            'acceptedBid': bid,
            'bids': bidsList, // Save the updated array with 'Rejected' statuses
            'bookedAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Bid accepted successfully! ✅',
              backgroundColor: Colors.green,
            );
            Navigator.pop(context); // Return to the previous screen
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
  // This code renders the visual layout of the Received Bids page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // EDGE CASE: If the listing is no longer 'Active' (e.g., already booked or finished),
    // show a static informational screen instead of the bidding interface.
    if (!isLoading && listingStatus != 'Active') {
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
                  listingStatus == 'Booked'
                      ? Icons.handshake
                      : Icons.check_circle,
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
                  listingStatus == 'Booked'
                      ? 'A collector has accepted your listing and is on their way.'
                      : 'The transaction has been successfully completed.',
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

    // MAIN UI: The active bidding interface
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
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if no collectors have placed a bid yet
          : bids.isEmpty
          ? const EmptyState(
              icon: Icons.monetization_on_outlined,
              title: 'No bids yet.',
              subtitle: 'Collectors are reviewing your listing...',
            )
          // Show the scrollable list of bids with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  // Because the list is sorted by amount, index 0 is always the highest bid
                  final isHighest = index == 0;

                  return Card(
                    elevation: isHighest
                        ? 4
                        : 2, // Higher elevation for the highest bid
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isHighest
                        ? const Color(0xFFE8F5E9)
                        : Colors
                              .white, // Light green background for highest bid
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Collector Info and Bid Amount
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
                                          // Show collector's rating if available
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
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${bid['amount']}',
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

                          // Bottom Row: "Highest Bid" Badge and Accept Button
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
