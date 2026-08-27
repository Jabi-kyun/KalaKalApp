import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'received_bids_page.dart';
import 'post_listing_page.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// WIDGET CLASS
// ============================================================================

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of all listings created by this household
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> listings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the household's listings as soon as the page opens
    _fetchListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & HELPER FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING ALL LISTINGS CREATED BY THIS HOUSEHOLD.
  /// It queries the Firestore 'listings' collection, filtering strictly by the
  /// current user's 'householdUid'. It orders them by creation date (newest first)
  /// so the user sees their most recent posts at the top.
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
          data['id'] = doc.id; // Attach document ID for editing/cancelling
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching listings: $e');
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
  /// Returns a specific color for Active, Booked, Finished, or Cancelled states.
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

  /// THESE CODES ARE FOR CANCELLING AN ACTIVE LISTING.
  /// It shows a confirmation dialog to prevent accidental cancellations.
  /// If confirmed, it updates the listing's status to 'Cancelled' in Firestore,
  /// instantly updates the local UI to reflect the change, and shows a success message.
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
        // 1. Update status in Firestore
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(docId)
            .update({
              'status': 'Cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });

        // 2. Update local UI instantly without needing to re-fetch from the database
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
  /// Creates small, space-efficient icon + text buttons that won't overflow the screen.
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
  // This code renders the visual layout of the Household's "My Listings" page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Listings', showBackButton: true),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if the household hasn't posted anything yet
          : listings.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No listings yet.',
              subtitle: 'Post your first scrap to get started!',
            )
          // Show the scrollable list of all listings with pull-to-refresh
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
                          // Top Row: Category and Status Chips
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

                          // Listing Details
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

                          // Bottom Row: Date and Dynamic Action Buttons
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
                                    // Show Edit, Bids, and Cancel buttons ONLY if the listing is Active
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
                                    // Show a static 'CANCELLED' chip if the listing was cancelled
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
