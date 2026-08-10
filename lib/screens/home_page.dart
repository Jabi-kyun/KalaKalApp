import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // ✅ NEW: OneSignal Import
import 'login_page.dart';
import 'household/post_listing_page.dart';
import 'household/my_listings_page.dart';
import 'household/edit_profile_page.dart';
import 'household/my_active_listings_page.dart';
import 'household/history_page.dart';
import 'collector/nearby_listings_page.dart';
import 'collector/my_bids_page.dart';
import 'collector/history_page.dart';
import 'collector/edit_profile_page.dart';
import 'admin/admin_dashboard_page.dart';
import 'widgets/kala_kal_app_bar.dart';
import 'widgets/action_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userRole = 'household';
  String userName = '';
  String? userProfilePic;
  bool isLoading = true;
  int activeListingsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userRole = doc.data()?['role'] ?? 'household';
          userName = doc.data()?['name'] ?? 'User';
          userProfilePic = doc.data()?['profilePic'];
          isLoading = false;
        });

        // ✅ NEW: Save OneSignal Player ID to Firestore
        String? playerId = await OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'onesignalId': playerId});
          debugPrint('✅ OneSignal ID saved: $playerId');
        }

        if (userRole == 'collector') {
          _fetchActiveListingsCount();
        }
      } else {
        throw Exception('Profile not found');
      }
    } catch (e) {
      debugPrint('❌ HomePage Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile. Using default.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchActiveListingsCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();

      setState(() {
        activeListingsCount = snapshot.docs.length;
      });
    } catch (e) {
      debugPrint('❌ Error fetching active listings count: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F7F3),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: KalaKalAppBar(
        title: 'KalaKalApp',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                userRole == 'household'
                    ? '🏠 Household'
                    : (userRole == 'admin' ? ' Admin' : '🚛 Collector'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: userRole == 'admin'
            ? _buildAdminDashboard()
            : (userRole == 'household'
                  ? _buildHouseholdDashboard()
                  : _buildCollectorDashboard()),
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.red.shade100,
              child: const Icon(
                Icons.admin_panel_settings,
                size: 32,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $userName! 👑',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage the KalaKalApp system.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
            ),
            icon: const Icon(Icons.dashboard, color: Colors.white),
            label: const Text(
              'OPEN ADMIN DASHBOARD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'LOGOUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHouseholdDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.green.shade100,
              backgroundImage: userProfilePic != null
                  ? MemoryImage(base64Decode(userProfilePic!))
                  : null,
              child: userProfilePic == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $userName! 👋',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sell your recyclables quickly and fairly.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              ActionCard(
                icon: Icons.add_circle_outline,
                title: 'Post Scrap',
                subtitle: 'Sell your recyclables',
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostListingPage()),
                ),
              ),
              ActionCard(
                icon: Icons.list_alt,
                title: 'My Listings',
                subtitle: 'View active posts',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyListingsPage()),
                ),
              ),
              ActionCard(
                icon: Icons.monetization_on,
                title: 'Received Bids',
                subtitle: 'Check collector offers',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyActiveListingsPage(),
                  ),
                ),
              ),
              ActionCard(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Past sales & ratings',
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HouseholdHistoryPage(),
                  ),
                ),
              ),
              ActionCard(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: 'Update your details',
                color: Colors.teal,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                  _loadUserData();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'LOGOUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectorDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.green.shade100,
              backgroundImage: userProfilePic != null
                  ? MemoryImage(base64Decode(userProfilePic!))
                  : null,
              child: userProfilePic == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $userName! ',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find nearby recyclables to collect.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              ActionCard(
                icon: Icons.list_alt,
                title: 'Nearby Listings',
                subtitle: 'Find scraps near you',
                color: Colors.green,
                badge: true,
                badgeCount: activeListingsCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NearbyListingsPage(),
                    ),
                  );
                  _fetchActiveListingsCount();
                },
              ),
              ActionCard(
                icon: Icons.monetization_on,
                title: 'My Bids',
                subtitle: 'Track your offers',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBidsPage()),
                ),
              ),
              ActionCard(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: 'Update your details',
                color: Colors.teal,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditCollectorProfilePage(),
                    ),
                  );
                  if (result == true) {
                    _loadUserData();
                  }
                },
              ),
              ActionCard(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Past collections',
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CollectorHistoryPage(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'LOGOUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
