import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the list of fetched user accounts
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> allUsers = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the user list as soon as the page opens
    _fetchUsers();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING ALL USERS.
  /// It queries the Firestore 'users' collection, attaches the document ID
  /// to each user object (needed for deletion), and updates the UI with
  /// the complete list of registered accounts.
  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      setState(() {
        allUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Attach the Firestore document ID for deletion
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching admin users: $e');
      setState(() => isLoading = false);
    }
  }

  /// THESE CODES ARE FOR DELETING A USER ACCOUNT.
  /// It shows a confirmation dialog to prevent accidental deletions. If confirmed,
  /// it permanently removes the user document from Firestore, updates the local
  /// list to reflect the change instantly, and shows a success or error TopSnackBar.
  Future<void> _deleteUser(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text(
          'This will permanently remove this user account from the database.',
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
        // 1. Delete the user document from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .delete();

        // 2. Remove from local UI list instantly so the admin sees the change
        setState(() {
          allUsers.removeWhere((item) => item['id'] == docId);
        });

        // 3. Show success message
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'User deleted successfully',
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
  // This code renders the visual layout of the Admin User Management page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Manage Users', showBackButton: true),
      body: isLoading
          // Show loading spinner while fetching data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state if no users exist in the database
          : allUsers.isEmpty
          ? const EmptyState(
              icon: Icons.people,
              title: 'No users found.',
              subtitle: 'The database is currently empty.',
            )
          // Show the scrollable list of users with pull-to-refresh
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allUsers.length,
                itemBuilder: (context, index) {
                  final user = allUsers[index];
                  final role = user['role'] ?? 'unknown';
                  // Capitalize the first letter of the role (e.g., 'admin' -> 'Admin')
                  final roleName = role[0].toUpperCase() + role.substring(1);

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        // Change avatar color and icon based on user role
                        backgroundColor: role == 'admin'
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          role == 'admin'
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: role == 'admin' ? Colors.red : Colors.blue,
                        ),
                      ),
                      title: Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['email'] ?? 'No email'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Displays the user's role as a small badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Delete Button that triggers the _deleteUser function
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteUser(user['id']),
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
