import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class AdminManageListingsPage extends StatefulWidget {
  const AdminManageListingsPage({super.key});

  @override
  State<AdminManageListingsPage> createState() =>
      _AdminManageListingsPageState();
}

class _AdminManageListingsPageState extends State<AdminManageListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of fetched listings
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> allListings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the listings as soon as the page opens
    _fetchListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING ALL LISTINGS.
  /// It queries the Firestore 'listings' collection, orders them by creation
  /// date (newest first), attaches the document ID to each item, and updates
  /// the UI with the complete list.
  Future<void> _fetchListings() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        allListings = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Attach the Firestore document ID for deletion
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching admin listings: $e');
      setState(() => isLoading = false);
    }
  }

  /// THESE CODES ARE FOR DELETING A LISTING.
  /// It shows a confirmation dialog to prevent accidental deletions. If confirmed,
  /// it permanently removes the document from Firestore, updates the local list
  /// to reflect the change instantly, and shows a success or error TopSnackBar.
  Future<void> _deleteListing(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text(
          'This will permanently remove this listing from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 1. Delete from Firestore
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(docId)
            .delete();

        // 2. Remove from local UI list instantly
        setState(() {
          allListings.removeWhere((item) => item['id'] == docId);
        });

        // 3. Show success message
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Listing deleted successfully',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        // Show error message if deletion fails
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Error deleting: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Admin Listings Management page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Manage Listings',
        showBackButton: true,
      ),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if no listings exist in the database
          : allListings.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2,
              title: 'No listings found.',
              subtitle: 'The database is currently empty.',
            )
          // Show the scrollable list of listings with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allListings.length,
                itemBuilder: (context, index) {
                  final item = allListings[index];
                  final status = item['status'] ?? 'Unknown';

                  // Format the Firestore Timestamp into a readable date string
                  final date = item['createdAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['createdAt'] as Timestamp).toDate())
                      : 'Unknown';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
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
                        '${item['householdName']} • ${item['quantity']} • $date',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Displays the current status (e.g., ACTIVE, FINISHED)
                          StatusChip(
                            label: status.toUpperCase(),
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(width: 8),

                          // Delete Button that triggers the _deleteListing function
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteListing(item['id']),
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
