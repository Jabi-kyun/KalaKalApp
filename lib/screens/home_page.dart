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

  // BADGE COUNTS FOR DASHBOARDS
  int activeListingsCount = 0; // Collector: Nearby scraps available
  int pendingBidCount = 0; // Collector: Booked/Pending Confirmation bids
  int householdPendingBidsCount =
      0; // Household: Active listings that have received bids

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// THIS FUNCTION FETCHES THE CURRENT USER'S DATA FROM FIRESTORE AND UPDATES THE UI STATE.
  /// IT REDIRECTS TO LOGIN IF NO USER IS FOUND. IT ALSO TRIGGERS SPECIFIC STATS FETCH BASED ON ROLE.
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

        // FETCH SPECIFIC DASHBOARD STATS BASED ON USER ROLE
        if (userRole == 'collector') {
          _fetchCollectorStats();
        } else if (userRole == 'household') {
          _fetchHouseholdStats();
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

  /// THIS FUNCTION COUNTS HOW MANY ACTIVE LISTINGS HAVE RECEIVED AT LEAST ONE BID FOR HOUSEHOLDS.
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
        final data = doc.data();
        final bidsList = (data['bids'] as List<dynamic>?);

        // IF THE LISTING HAS A BIDS ARRAY AND IT'S NOT EMPTY, COUNT IT
        if (bidsList != null && bidsList.isNotEmpty) {
          count++;
        }
      }

      setState(() {
        householdPendingBidsCount = count;
      });
    } catch (e) {
      debugPrint('❌ Error fetching household stats: $e');
    }
  }

  /// THIS FUNCTION COUNTS NEARBY ACTIVE LISTINGS AND PENDING BID ACTIONS FOR COLLECTORS.
  Future<void> _fetchCollectorStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // GET NEARBY ACTIVE LISTINGS COUNT
      final nearbySnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();

      // GET BOOKED AND PENDING CONFIRMATION LISTINGS
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', whereIn: ['Booked', 'Pending Confirmation'])
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

  /// THIS FUNCTION DISPLAYS A CONFIRMATION DIALOG AND SIGNS THE USER OUT OF FIREBASE AUTH.
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

  /// THIS FUNCTION HANDLES THE SELECTION LOGIC FOR THE THREE-DOTS POPUP MENU IN THE APPBAR.
  void _onMenuSelected(String value) {
    switch (value) {
      case 'edit_profile':
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

  /// THIS FUNCTION BUILDS THE DASHBOARD UI SPECIFICALLY FOR ADMIN USERS.
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

  /// THIS FUNCTION BUILDS THE DASHBOARD UI FOR HOUSEHOLD USERS WITH DYNAMIC BADGES.
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
              // ADDED BADGE FOR HOUSEHOLD RECEIVED BIDS
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
                  _fetchHouseholdStats(); // REFRESH BADGE COUNT AFTER RETURNING
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

  /// THIS FUNCTION BUILDS THE DASHBOARD UI FOR COLLECTOR USERS WITH DYNAMIC BADGES.
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
                  _fetchCollectorStats(); // REFRESH BOTH BADGES
                },
              ),
              ActionCard(
                icon: Icons.monetization_on,
                title: 'My Bids',
                subtitle: 'Track your offers',
                color: Colors.orange,
                badge: true,
                badgeCount: pendingBidCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBidsPage()),
                  );
                  _fetchCollectorStats(); // REFRESH BOTH BADGES
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
      ],
    );
  }
}
