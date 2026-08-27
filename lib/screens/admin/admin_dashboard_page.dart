import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/stat_card.dart';
import 'admin_manage_listings_page.dart';
import 'admin_manage_users_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the statistical data fetched from the database
  // ==========================================================================

  int totalUsers = 0;
  int activeListings = 0;
  int completedTransactions = 0;
  bool isLoading = true; // Shows a loading spinner while data is being fetched

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch the statistics as soon as the page loads
    _fetchStats();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR FETCHING SYSTEM STATISTICS.
  /// It queries Firestore to count the total number of registered users,
  /// currently active scrap listings, and successfully completed transactions
  /// to display on the admin dashboard overview.
  Future<void> _fetchStats() async {
    try {
      // Fetch all users to count total registered accounts
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Fetch listings that are currently marked as 'Active'
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();

      // Fetch listings that have been marked as 'Finished' (completed transactions)
      final finishedSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .get();

      // Update the UI with the counted numbers
      setState(() {
        totalUsers = usersSnapshot.docs.length;
        activeListings = activeSnapshot.docs.length;
        completedTransactions = finishedSnapshot.docs.length;
        isLoading = false; // Hide the loading spinner
      });
    } catch (e) {
      debugPrint('❌ Error fetching admin stats: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // This code renders the visual layout of the Admin Dashboard
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while the statistics are being fetched
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F7F3),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(
        title: 'Admin Dashboard',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION: System Overview Statistics ---
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // Row 1: Total Users and Active Listings
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Users',
                    value: totalUsers.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Active Listings',
                    value: activeListings.toString(),
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Completed and Cancelled Transactions
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Completed',
                    value: completedTransactions.toString(),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Cancelled',
                    value: '0',
                    color: Colors.red,
                  ), // Placeholder for future feature
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- SECTION: Management Navigation Grid ---
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // Grid of clickable cards that navigate to specific admin tools
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _AdminActionCard(
                    icon: Icons.inventory_2,
                    title: 'Manage Listings',
                    subtitle: 'View & delete posts',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminManageListingsPage(),
                      ),
                    ),
                  ),
                  _AdminActionCard(
                    icon: Icons.people,
                    title: 'Manage Users',
                    subtitle: 'View & delete accounts',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminManageUsersPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

/// HELPER WIDGET FOR MANAGEMENT CARDS.
/// This creates the reusable, clickable cards seen in the "Management" grid
/// that navigate the admin to specific moderation pages.
class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
