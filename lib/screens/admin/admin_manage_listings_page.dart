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

// THIS CLASS DEFINES THE ADMIN MANAGE LISTINGS PAGE.
// IT ALLOWS ADMINS TO VIEW ALL LISTINGS IN THE SYSTEM AND DELETE THEM IF NECESSARY.
class AdminManageListingsPage extends StatefulWidget {
  const AdminManageListingsPage({super.key});

  @override
  State<AdminManageListingsPage> createState() =>
      _AdminManageListingsPageState();
}

class _AdminManageListingsPageState extends State<AdminManageListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF FETCHED LISTINGS.
  bool isLoading = true;
  List<Map<String, dynamic>> allListings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE LISTINGS AS SOON AS THE PAGE OPENS.
    _fetchListings();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES ALL LISTINGS.
  /// IT QUERIES THE FIRESTORE 'LISTINGS' COLLECTION, ORDERS THEM BY CREATION
  /// DATE (NEWEST FIRST), ATTACHES THE DOCUMENT ID TO EACH ITEM, AND UPDATES
  /// THE UI WITH THE COMPLETE LIST.
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
          data['id'] = doc.id; // ATTACH THE FIRESTORE DOCUMENT ID FOR DELETION
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching admin listings: $e');
      setState(() => isLoading = false);
    }
  }

  /// THIS FUNCTION HANDLES DELETING A LISTING.
  /// IT SHOWS A CONFIRMATION DIALOG TO PREVENT ACCIDENTAL DELETIONS. IF CONFIRMED,
  /// IT PERMANENTLY REMOVES THE DOCUMENT FROM FIRESTORE, UPDATES THE LOCAL LIST
  /// TO REFLECT THE CHANGE INSTANTLY, AND SHOWS A SUCCESS OR ERROR TOPSNACKBAR.
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
        // 1. DELETE FROM FIRESTORE
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(docId)
            .delete();

        // 2. REMOVE FROM LOCAL UI LIST INSTANTLY
        setState(() {
          allListings.removeWhere((item) => item['id'] == docId);
        });

        // 3. SHOW SUCCESS MESSAGE
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Listing deleted successfully',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        // SHOW ERROR MESSAGE IF DELETION FAILS
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
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE ADMIN LISTINGS MANAGEMENT PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Manage Listings',
        showBackButton: true,
      ),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF NO LISTINGS EXIST IN THE DATABASE
          : allListings.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2,
              title: 'No listings found.',
              subtitle: 'The database is currently empty.',
            )
          // SHOW THE SCROLLABLE LIST OF LISTINGS WITH PULL-TO-REFRESH
          : RefreshIndicator(
              onRefresh: _fetchListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allListings.length,
                itemBuilder: (context, index) {
                  final item = allListings[index];
                  final status = item['status'] ?? 'Unknown';

                  // FORMAT THE FIRESTORE TIMESTAMP INTO A READABLE DATE STRING
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
                          // DISPLAYS THE CURRENT STATUS (E.G., ACTIVE, FINISHED)
                          StatusChip(
                            label: status.toUpperCase(),
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(width: 8),

                          // DELETE BUTTON THAT TRIGGERS THE _DELETELISTING FUNCTION
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
