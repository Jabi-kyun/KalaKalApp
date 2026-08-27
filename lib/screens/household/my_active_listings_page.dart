import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import 'received_bids_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class MyActiveListingsPage extends StatefulWidget {
  const MyActiveListingsPage({super.key});

  @override
  State<MyActiveListingsPage> createState() => _MyActiveListingsPageState();
}

class _MyActiveListingsPageState extends State<MyActiveListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of the household's active listings
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> activeListings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch active listings as soon as the page opens
    _fetchActiveListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING THE HOUSEHOLD'S ACTIVE LISTINGS.
  /// It queries the Firestore 'listings' collection, strictly filtering for
  /// documents where the 'householdUid' matches the current user AND the
  /// 'status' is exactly 'Active'. It orders them by creation date (newest first)
  /// so the household can easily tap into them to view received bids.
  Future<void> _fetchActiveListings() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Active')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        activeListings = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Attach document ID for navigation
          return data;
        }).toList();
        isLoading = false; // Hide loading spinner
      });
    } catch (e) {
      debugPrint('❌ Error fetching active listings: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Active Listings page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Received Bids', showBackButton: true),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if the household has no active listings
          : activeListings.isEmpty
          ? const EmptyState(
              icon: Icons.monetization_on_outlined,
              title: 'No active listings.',
              subtitle: 'Post a scrap to start receiving bids!',
            )
          // Show the scrollable list of active listings with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchActiveListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeListings.length,
                itemBuilder: (context, index) {
                  final item = activeListings[index];

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.recycling,
                          color: Colors.green.shade700,
                        ),
                      ),
                      title: Text(
                        item['category'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item['quantity']} • ${item['description']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      // Tapping the card navigates to the Received Bids page for this specific listing
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceivedBidsPage(
                              listingId: item['id'],
                              listingCategory: item['category'] ?? 'Unknown',
                              listingQuantity: item['quantity'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
