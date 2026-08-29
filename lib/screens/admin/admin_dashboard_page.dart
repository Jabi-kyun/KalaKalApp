import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/stat_card.dart';
import 'admin_manage_listings_page.dart';
import 'admin_manage_users_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE ADMIN DASHBOARD PAGE.
// IT DISPLAYS SYSTEM STATISTICS AND PROVIDES NAVIGATION TO ADMIN MANAGEMENT TOOLS.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE STATISTICAL DATA FETCHED FROM THE DATABASE.
  int totalUsers = 0;
  int activeListings = 0;
  int completedTransactions = 0;
  bool isLoading = true; // SHOWS A LOADING SPINNER WHILE DATA IS BEING FETCHED

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY FETCH THE STATISTICS AS SOON AS THE PAGE LOADS.
    _fetchStats();
  }

  // ==========================================================================
  // 3. DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION FETCHES SYSTEM STATISTICS.
  /// IT QUERIES FIRESTORE TO COUNT THE TOTAL NUMBER OF REGISTERED USERS,
  /// CURRENTLY ACTIVE SCRAP LISTINGS, AND SUCCESSFULLY COMPLETED TRANSACTIONS
  /// TO DISPLAY ON THE ADMIN DASHBOARD OVERVIEW.
  Future<void> _fetchStats() async {
    try {
      // FETCH ALL USERS TO COUNT TOTAL REGISTERED ACCOUNTS.
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // FETCH LISTINGS THAT ARE CURRENTLY MARKED AS 'ACTIVE'.
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();

      // FETCH LISTINGS THAT HAVE BEEN MARKED AS 'FINISHED' (COMPLETED TRANSACTIONS).
      final finishedSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .get();

      // UPDATE THE UI WITH THE COUNTED NUMBERS.
      setState(() {
        totalUsers = usersSnapshot.docs.length;
        activeListings = activeSnapshot.docs.length;
        completedTransactions = finishedSnapshot.docs.length;
        isLoading = false; // HIDE THE LOADING SPINNER.
      });
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      setState(() => isLoading = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE ADMIN DASHBOARD.
  @override
  Widget build(BuildContext context) {
    // SHOW A LOADING SPINNER WHILE THE STATISTICS ARE BEING FETCHED.
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
            // --- SECTION: SYSTEM OVERVIEW STATISTICS ---
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // ROW 1: TOTAL USERS AND ACTIVE LISTINGS.
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

            // ROW 2: COMPLETED AND CANCELLED TRANSACTIONS.
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
                  ), // PLACEHOLDER FOR FUTURE FEATURE
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- SECTION: MANAGEMENT NAVIGATION GRID ---
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // GRID OF CLICKABLE CARDS THAT NAVIGATE TO SPECIFIC ADMIN TOOLS.
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
/// THIS CREATES THE REUSABLE, CLICKABLE CARDS SEEN IN THE "MANAGEMENT" GRID
/// THAT NAVIGATE THE ADMIN TO SPECIFIC MODERATION PAGES.
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
