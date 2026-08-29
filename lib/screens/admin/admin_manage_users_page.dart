import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE ADMIN MANAGE USERS PAGE.
// IT ALLOWS ADMINS TO VIEW ALL REGISTERED USER ACCOUNTS AND DELETE THEM IF NECESSARY.
class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE LOADING STATE AND THE LIST OF FETCHED USER ACCOUNTS.
  bool isLoading = true;
  List<Map<String, dynamic>> allUsers = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE USER LIST AS SOON AS THE PAGE OPENS.
    _fetchUsers();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES ALL USERS.
  /// IT QUERIES THE FIRESTORE 'USERS' COLLECTION, ATTACHES THE DOCUMENT ID
  /// TO EACH USER OBJECT (NEEDED FOR DELETION), AND UPDATES THE UI WITH
  /// THE COMPLETE LIST OF REGISTERED ACCOUNTS.
  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      setState(() {
        allUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // ATTACH THE FIRESTORE DOCUMENT ID FOR DELETION
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
      setState(() => isLoading = false);
    }
  }

  /// THIS FUNCTION HANDLES DELETING A USER ACCOUNT.
  /// IT SHOWS A CONFIRMATION DIALOG TO PREVENT ACCIDENTAL DELETIONS. IF CONFIRMED,
  /// IT PERMANENTLY REMOVES THE USER DOCUMENT FROM FIRESTORE, UPDATES THE LOCAL
  /// LIST TO REFLECT THE CHANGE INSTANTLY, AND SHOWS A SUCCESS OR ERROR TOPSNACKBAR.
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
        // 1. DELETE THE USER DOCUMENT FROM FIRESTORE
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .delete();

        // 2. REMOVE FROM LOCAL UI LIST INSTANTLY SO THE ADMIN SEES THE CHANGE
        setState(() {
          allUsers.removeWhere((item) => item['id'] == docId);
        });

        // 3. SHOW SUCCESS MESSAGE
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'User deleted successfully',
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

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE ADMIN USER MANAGEMENT PAGE.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Manage Users', showBackButton: true),
      body: isLoading
          // SHOW LOADING SPINNER WHILE FETCHING DATA
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // SHOW EMPTY STATE IF NO USERS EXIST IN THE DATABASE
          : allUsers.isEmpty
          ? const EmptyState(
              icon: Icons.people,
              title: 'No users found.',
              subtitle: 'The database is currently empty.',
            )
          // SHOW THE SCROLLABLE LIST OF USERS WITH PULL-TO-REFRESH
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allUsers.length,
                itemBuilder: (context, index) {
                  final user = allUsers[index];
                  final role = user['role'] ?? 'unknown';
                  // CAPITALIZE THE FIRST LETTER OF THE ROLE (E.G., 'ADMIN' -> 'ADMIN')
                  final roleName = role[0].toUpperCase() + role.substring(1);

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        // CHANGE AVATAR COLOR AND ICON BASED ON USER ROLE
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
                          // DISPLAYS THE USER'S ROLE AS A SMALL BADGE
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

                          // DELETE BUTTON THAT TRIGGERS THE _DELETEUSER FUNCTION
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
