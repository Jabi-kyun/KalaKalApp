import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/empty_state.dart';
import 'received_bids_page.dart';

class MyActiveListingsPage extends StatefulWidget {
  const MyActiveListingsPage({super.key});

  @override
  State<MyActiveListingsPage> createState() => _MyActiveListingsPageState();
}

class _MyActiveListingsPageState extends State<MyActiveListingsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> activeListings = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveListings();
  }

  Future<void> _fetchActiveListings() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      //  Only gets Active listings for this specific household
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('householdUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Active')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        activeListings = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching active listings: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Received Bids', showBackButton: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : activeListings.isEmpty
          ? const EmptyState(
              icon: Icons.monetization_on_outlined,
              title: 'No active listings.',
              subtitle: 'Post a scrap to start receiving bids!',
            )
          : RefreshIndicator(
              onRefresh: _fetchActiveListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeListings.length,
                itemBuilder: (context, index) {
                  final item = activeListings[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        '${item['quantity']} • ${item['description']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceivedBidsPage(
                              listingId: item['id'],
                              listingCategory: item['category'] ?? 'Unknown',
                              listingQuantity: item['quantity'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
