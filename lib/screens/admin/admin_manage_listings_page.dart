import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';
import '../widgets/top_snackbar.dart'; // ✅ ADDED

class AdminManageListingsPage extends StatefulWidget {
  const AdminManageListingsPage({super.key});

  @override
  State<AdminManageListingsPage> createState() =>
      _AdminManageListingsPageState();
}

class _AdminManageListingsPageState extends State<AdminManageListingsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> allListings = [];

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

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
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching admin listings: $e');
      setState(() => isLoading = false);
    }
  }

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
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(docId)
            .delete();
        setState(() {
          allListings.removeWhere((item) => item['id'] == docId);
        });
        if (mounted) {
          // ✅ UPDATED TO TOP SNACKBAR
          TopSnackBar.show(
            context,
            message: 'Listing deleted successfully',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        if (mounted) {
          // ✅ UPDATED TO TOP SNACKBAR
          TopSnackBar.show(
            context,
            message: 'Error deleting: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Manage Listings',
        showBackButton: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : allListings.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2,
              title: 'No listings found.',
              subtitle: 'The database is currently empty.',
            )
          : RefreshIndicator(
              onRefresh: _fetchListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allListings.length,
                itemBuilder: (context, index) {
                  final item = allListings[index];
                  final status = item['status'] ?? 'Unknown';
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
                          StatusChip(
                            label: status.toUpperCase(),
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(width: 8),
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
