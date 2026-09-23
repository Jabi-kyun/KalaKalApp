import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/top_snackbar.dart';
import 'InAppRoutePage.dart';

class MyBidsPage extends StatefulWidget {
  const MyBidsPage({super.key});
  @override
  State<MyBidsPage> createState() => _MyBidsPageState();
}

class _MyBidsPageState extends State<MyBidsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> myBids = [];

  String getSafeDisplay(dynamic value, String fallback) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _fetchMyBids();
  }

  Future<void> _fetchMyBids() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Added 'Pending' and 'Scheduled' to the query
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where(
            'status',
            whereIn: [
              'Active',
              'Booked',
              'Pending Confirmation',
              'Pending',
              'Scheduled',
            ],
          )
          .get();

      List<Map<String, dynamic>> tempBids = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final bidsList = (data['bids'] as List<dynamic>?);
        if (bidsList != null) {
          final myBid = bidsList.firstWhere(
            (bid) => (bid as Map)['collectorUid'] == user.uid,
            orElse: () => null,
          );
          if (myBid != null) {
            tempBids.add({
              ...data,
              'myBidAmount': myBid['amount'],
              'myBidStatus': myBid['status'] ?? 'Pending',
              'bidAt': myBid['bidAt'],
            });
          }
        }
      }
      tempBids.sort((a, b) {
        final dateA = a['bidAt'] is Timestamp
            ? (a['bidAt'] as Timestamp).toDate()
            : DateTime(2000);
        final dateB = b['bidAt'] is Timestamp
            ? (b['bidAt'] as Timestamp).toDate()
            : DateTime(2000);
        return dateB.compareTo(dateA);
      });
      if (mounted) {
        setState(() {
          myBids = tempBids;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching my bids: $e');
      if (mounted) {
        setState(() => isLoading = false);
        TopSnackBar.show(
          context,
          message: 'Failed to load bids: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  // NEW: Collector confirms the scheduled time
  Future<void> _confirmSchedule(String listingId, String timeSlotDocId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final listingRef = FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId);

      batch.update(listingRef, {
        'status': 'Scheduled',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      final slotRef = FirebaseFirestore.instance
          .collection('timeSlots')
          .doc(timeSlotDocId);
      batch.update(slotRef, {'status': 'confirmed'});

      await batch.commit();

      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Schedule confirmed!',
          backgroundColor: Colors.green,
        );
        _fetchMyBids();
      }
    } catch (e) {
      if (mounted)
        TopSnackBar.show(
          context,
          message: 'Error confirming: $e',
          backgroundColor: Colors.red,
        );
    }
  }

  // NEW: Collector declines the scheduled time
  Future<void> _declineSchedule(String listingId, String timeSlotDocId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final listingRef = FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId);

      batch.update(listingRef, {
        'status': 'Declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      final slotRef = FirebaseFirestore.instance
          .collection('timeSlots')
          .doc(timeSlotDocId);
      batch.update(slotRef, {'isBooked': false, 'status': 'available'});

      await batch.commit();

      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Schedule declined.',
          backgroundColor: Colors.orange,
        );
        _fetchMyBids();
      }
    } catch (e) {
      if (mounted)
        TopSnackBar.show(
          context,
          message: 'Error declining: $e',
          backgroundColor: Colors.red,
        );
    }
  }

  // EXISTING: Collector confirms physical pickup is done
  Future<void> _confirmPickup(String listingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Pickup?'),
        content: const Text(
          'Have you successfully collected the recyclables? The household will be notified to confirm completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final docRef = FirebaseFirestore.instance
            .collection('listings')
            .doc(listingId);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data()!;
          List<dynamic> bidsList = List<dynamic>.from(data['bids'] ?? []);
          for (var i = 0; i < bidsList.length; i++) {
            if (bidsList[i]['collectorUid'] == user.uid) {
              bidsList[i]['status'] = 'Accepted';
              break;
            }
          }
          await docRef.update({
            'status': 'Pending Confirmation',
            'pendingConfirmationAt': FieldValue.serverTimestamp(),
            'bids': bidsList,
          });
          if (mounted) {
            TopSnackBar.show(
              context,
              message: 'Pickup confirmed! Waiting for household.',
              backgroundColor: Colors.orange,
            );
            _fetchMyBids();
          }
        }
      } catch (e) {
        if (mounted)
          TopSnackBar.show(
            context,
            message: 'Error: $e',
            backgroundColor: Colors.red,
          );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'booked':
        return Colors.blue;
      case 'pending confirmation':
        return Colors.purple;
      case 'finished':
        return Colors.grey;
      case 'declined':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'My Bids', showBackButton: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : myBids.isEmpty
          ? const EmptyState(
              icon: Icons.gavel,
              title: 'No bids placed yet.',
              subtitle: 'Browse nearby listings and make your first offer!',
            )
          : RefreshIndicator(
              onRefresh: _fetchMyBids,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myBids.length,
                itemBuilder: (context, index) {
                  final item = myBids[index];
                  final listingStatus = item['status'] ?? 'Active';
                  final bidStatus = item['myBidStatus'] ?? 'Pending';
                  final date = item['bidAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['bidAt'] as Timestamp).toDate())
                      : 'Unknown Date';

                  // Extract scheduling info
                  final scheduledDate = item['scheduledDate'] ?? '';
                  final timeSlot = item['timeSlot'] ?? '';
                  final timeSlotDocId =
                      '${item['winnerUid']}_${scheduledDate}_${timeSlot.split('-')[0]}';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(
                                label: item['category'] ?? 'Unknown',
                                backgroundColor: Colors.green,
                              ),
                              StatusChip(
                                label: listingStatus,
                                backgroundColor: _getStatusColor(listingStatus),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            getSafeDisplay(
                              item['householdName'],
                              'Anonymous Household',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['description'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SCHEDULING INFO DISPLAY
                          if (listingStatus == 'Pending' ||
                              listingStatus == 'Scheduled') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Scheduled Pickup',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '$scheduledDate at $timeSlot',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Offer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'P${item['myBidAmount']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      bidStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(bidStatus),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // BUTTONS BASED ON STATUS
                          if (listingStatus == 'Pending') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmSchedule(
                                      item['id'],
                                      timeSlotDocId,
                                    ),
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'CONFIRM TIME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _declineSchedule(
                                      item['id'],
                                      timeSlotDocId,
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'DECLINE',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if ((listingStatus == 'Booked' ||
                                  listingStatus == 'Scheduled' ||
                                  listingStatus == 'Pending Confirmation') &&
                              item['myBidStatus'] == 'Accepted' &&
                              item['location'] != null) ...[
                            if (listingStatus == 'Booked' ||
                                listingStatus == 'Scheduled')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final loc = item['location'];
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InAppRoutePage(
                                          householdName: getSafeDisplay(
                                            item['householdName'],
                                            'Household',
                                          ),
                                          address:
                                              item['address'] ??
                                              'No address provided',
                                          destLat: double.parse(
                                            loc['latitude'].toString(),
                                          ),
                                          destLng: double.parse(
                                            loc['longitude'].toString(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'NAVIGATE TO PICKUP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmPickup(item['id']),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  listingStatus == 'Pending Confirmation'
                                      ? 'WAITING FOR HOUSEHOLD...'
                                      : 'CONFIRM PICKUP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      listingStatus == 'Pending Confirmation'
                                      ? Colors.purple
                                      : Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (item['myBidStatus'] == 'Rejected' ||
                              listingStatus == 'Declined')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Center(
                                child: Text(
                                  'Your bid was not accepted.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
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
