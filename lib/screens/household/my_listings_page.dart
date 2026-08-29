import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'received_bids_page.dart';
import 'post_listing_page.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE MY LISTINGS PAGE FOR HOUSEHOLDS.
// IT ALLOWS USERS TO VIEW, EDIT, AND CANCEL THEIR POSTED SCRAP LISTINGS.
class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF ALL LISTINGS CREATED BY THIS HOUSEHOLD.
  bool isLoading = true;
  List<Map<String, dynamic>> listings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE HOUSEHOLD'S LISTINGS AS SOON AS THE PAGE OPENS.
    _fetchListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & HELPER FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES ALL LISTINGS CREATED BY THIS HOUSEHOLD.
  /// IT QUERIES THE FIRESTORE 'LISTINGS' COLLECTION, FILTERING STRICTLY BY THE
  /// CURRENT USER'S 'HOUSEHOLDUID'. IT ORDERS THEM BY CREATION DATE (NEWEST FIRST)
  /// SO THE USER SEES THEIR MOST RECENT POSTS AT THE TOP.
  Future<void> _fetchListings() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        listings = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // ATTACH DOCUMENT ID FOR EDITING/CANCELLING
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching listings: $e');
      setState(() => isLoading = false);
      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Failed to load listings: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// HELPER FUNCTION TO ASSIGN COLORS BASED ON LISTING STATUS.
  /// RETURNS A SPECIFIC COLOR FOR ACTIVE, BOOKED, FINISHED, OR CANCELLED STATES.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'booked':
        return Colors.orange;
      case 'finished':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==========================================================================
  // 4. USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION HANDLES CANCELLING AN ACTIVE LISTING.
  /// IT SHOWS A CONFIRMATION DIALOG TO PREVENT ACCIDENTAL CANCELLATIONS.
  /// IF CONFIRMED, IT UPDATES THE LISTING'S STATUS TO 'CANCELLED' IN FIRESTORE,
  /// INSTANTLY UPDATES THE LOCAL UI TO REFLECT THE CHANGE, AND SHOWS A SUCCESS MESSAGE.
  Future<void> _cancelListing(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Listing?'),
        content: const Text(
          'Are you sure you want to cancel this listing? '
          'This action cannot be undone and collectors will no longer see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 1. UPDATE STATUS IN FIRESTORE
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(docId)
            .update({
              'status': 'Cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });

        // 2. UPDATE LOCAL UI INSTANTLY WITHOUT NEEDING TO RE-FETCH FROM THE DATABASE
        setState(() {
          final index = listings.indexWhere((item) => item['id'] == docId);
          if (index != -1) {
            listings[index]['status'] = 'Cancelled';
            listings[index]['cancelledAt'] = DateTime.now();
          }
        });

        if (!mounted) return;
        TopSnackBar.show(
          context,
          message: 'Listing cancelled successfully.',
          backgroundColor: Colors.orange,
        );
      } catch (e) {
        if (!mounted) return;
        TopSnackBar.show(
          context,
          message: 'Error cancelling listing: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// HELPER UI WIDGET FOR COMPACT ACTION BUTTONS.
  /// CREATES SMALL, SPACE-EFFICIENT ICON + TEXT BUTTONS THAT WON'T OVERFLOW THE SCREEN.
  Widget _buildCompactButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 5. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE HOUSEHOLD'S MY LISTINGS PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Listings', showBackButton: true),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF THE HOUSEHOLD HASN'T POSTED ANYTHING YET
          : listings.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No listings yet.',
              subtitle: 'Post your first scrap to get started!',
            )
          // SHOW THE SCROLLABLE LIST OF ALL LISTINGS WITH PULL-TO-REFRESH
          : RefreshIndicator(
              onRefresh: _fetchListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final item = listings[index];
                  final status = item['status'] ?? 'Active';
                  final date = item['createdAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['createdAt'] as Timestamp).toDate())
                      : 'Unknown Date';

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
                              StatusChip(
                                label: status,
                                backgroundColor: _getStatusColor(status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // LISTING DETAILS
                          Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['description'] ?? 'No description',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          // BOTTOM ROW: DATE AND DYNAMIC ACTION BUTTONS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // SHOW EDIT, BIDS, AND CANCEL BUTTONS ONLY IF THE LISTING IS ACTIVE
                                    if (status == 'Active') ...[
                                      _buildCompactButton(
                                        Icons.edit_outlined,
                                        'Edit',
                                        Colors.blue,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PostListingPage(
                                              existingListing: item,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildCompactButton(
                                        Icons.monetization_on,
                                        'Bids',
                                        Colors.orange,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReceivedBidsPage(
                                              listingId: item['id'],
                                              listingCategory:
                                                  item['category'] ?? 'Unknown',
                                              listingQuantity:
                                                  item['quantity'] ?? '',
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildCompactButton(
                                        Icons.cancel_outlined,
                                        'Cancel',
                                        Colors.red,
                                        () => _cancelListing(item['id']),
                                      ),
                                    ]
                                    // SHOW A STATIC 'CANCELLED' CHIP IF THE LISTING WAS CANCELLED
                                    else if (status == 'Cancelled')
                                      const Chip(
                                        label: Text(
                                          'CANCELLED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                        backgroundColor: Colors.grey,
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
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