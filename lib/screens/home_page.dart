import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'collector/CollectorMapHomeScreen.dart';
import 'admin/admin_dashboard_page.dart';
import 'about_us_page.dart';
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
  int pendingBidCount = 0;
  int householdPendingBidsCount = 0;

  StreamSubscription? _listingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _listingsSubscription?.cancel();
    super.dispose();
  }

  void _startRealTimeListener(String uid) {
    _listingsSubscription = FirebaseFirestore.instance
        .collection('listings')
        .where('householdUid', isEqualTo: uid)
        .where('status', isEqualTo: 'Active')
        .snapshots()
        .listen((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final bids = doc.data()['bids'] as List<dynamic>?;
            if (bids != null && bids.isNotEmpty) count++;
          }
          if (mounted) {
            setState(() {
              householdPendingBidsCount = count;
            });
          }
        });
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

        if (userRole == 'collector') {
          _fetchCollectorStats();
        } else if (userRole == 'household') {
          _fetchHouseholdStats();
          _startRealTimeListener(user.uid);
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

  Future<void> _fetchHouseholdStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Active')
          .get();
      int count = 0;
      for (var doc in snapshot.docs) {
        final bids = doc.data()['bids'] as List<dynamic>?;
        if (bids != null && bids.isNotEmpty) count++;
      }
      setState(() {
        householdPendingBidsCount = count;
      });
    } catch (e) {
      debugPrint('❌ Error fetching household stats: $e');
    }
  }

  Future<void> _fetchCollectorStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final nearbySnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where(
            'status',
            whereIn: ['Booked', 'Pending Confirmation', 'Scheduled'],
          )
          .get();
      int bidCount = 0;
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data();
        final bidsList = (data['bids'] as List<dynamic>?);
        if (bidsList != null) {
          final myBid = bidsList.firstWhere(
            (bid) =>
                (bid as Map)['collectorUid'] == user.uid &&
                (bid as Map)['status'] == 'Accepted',
            orElse: () => null,
          );
          if (myBid != null) bidCount++;
        }
      }
      setState(() {
        activeListingsCount = nearbySnapshot.docs.length;
        pendingBidCount = bidCount;
      });
    } catch (e) {
      debugPrint('❌ Error fetching collector stats: $e');
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

  void _onMenuSelected(String value) {
    switch (value) {
      case 'edit_profile': // ✅ RESTORED EDIT PROFILE
        if (userRole == 'collector') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditCollectorProfilePage()),
          ).then((_) => _loadUserData());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfilePage()),
          ).then((_) => _loadUserData());
        }
        break;
      case 'about_us':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutUsPage()),
        );
        break;
      case 'logout':
        _logout();
        break;
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                // ✅ RESTORED IN MENU
                value: 'edit_profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline, color: Colors.green),
                  title: Text('Edit Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'about_us',
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blue),
                  title: Text('About Us'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userRole == 'collector'
          ? _buildCollectorDashboard()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: userRole == 'admin'
                  ? _buildAdminDashboard()
                  : _buildHouseholdDashboard(),
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
                badge: true,
                badgeCount: householdPendingBidsCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyActiveListingsPage(),
                    ),
                  );
                  _fetchHouseholdStats();
                },
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
            ],
          ),
        ),
      ],
    );
  }

  // ✅ UPDATED: CLEANER DASHBOARD WITH ONLY 2 CARDS (Profile moved to top-right menu)
  Widget _buildCollectorDashboard() {
    return Stack(
      children: [
        Positioned.fill(child: CollectorMapHomeScreen()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: _buildFloatingActionCard(
                  icon: Icons.monetization_on,
                  title: 'My Bids',
                  subtitle: '$pendingBidCount active',
                  color: Colors.orange,
                  badge: pendingBidCount > 0,
                  badgeCount: pendingBidCount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBidsPage()),
                  ).then((_) => _fetchCollectorStats()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFloatingActionCard(
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool badge = false,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (badge && badgeCount != null && badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount! > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
