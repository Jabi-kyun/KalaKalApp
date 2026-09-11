import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectorReviewPage extends StatefulWidget {
  final String collectorUid;
  final String collectorName;

  const CollectorReviewPage({
    super.key,
    required this.collectorUid,
    required this.collectorName,
  });

  @override
  State<CollectorReviewPage> createState() => _CollectorReviewPageState();
}

class _CollectorReviewPageState extends State<CollectorReviewPage> {
  String? profilePicBase64;
  List<Map<String, dynamic>> pastReviews = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollectorData();
  }

  Future<void> _fetchCollectorData() async {
    try {
      // 1. Fetch Profile Picture from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.collectorUid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (data['profilePic'] != null &&
            data['profilePic'].toString().isNotEmpty) {
          profilePicBase64 = data['profilePic'] as String?;
        }
      }

      // 2. Fetch ALL finished transactions
      final finishedSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Finished')
          .orderBy('completedAt', descending: true)
          .get();

      debugPrint(
        '🔍 Found ${finishedSnapshot.docs.length} finished listings total',
      );
      debugPrint('🎯 Looking for collector UID: ${widget.collectorUid}');

      // 3. Filter locally in Dart and extract ratings
      final reviews = <Map<String, dynamic>>[];
      for (var doc in finishedSnapshot.docs) {
        final data = doc.data();
        final acceptedBid = data['acceptedBid'] as Map<String, dynamic>?;

        // Read 'rating' from inside acceptedBid, not 'collectorRating' from root
        final rating = acceptedBid?['rating'] ?? 0;

        debugPrint('📄 Listing: ${doc.id}');
        debugPrint('   - winnerUid: ${data['winnerUid']}');
        debugPrint(
          '   - acceptedBid?.collectorUid: ${acceptedBid?['collectorUid']}',
        );
        debugPrint('   - rating (from acceptedBid): $rating');
        debugPrint(
          '   - Match: ${acceptedBid?['collectorUid'] == widget.collectorUid && rating > 0}',
        );

        if (acceptedBid != null &&
            acceptedBid['collectorUid'] == widget.collectorUid &&
            rating > 0) {

            reviews.add({
            'rating': rating,
            'date': data['completedAt'],
            'category': data['category'] ?? 'Scrap',
          });
          debugPrint('✅ ADDED: Rating $rating for ${data['category']}');
        }
      }

      debugPrint('📊 Total reviews found: ${reviews.length}');

      setState(() {
        pastReviews = reviews;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching collector review data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.collectorName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                        (profilePicBase64 != null &&
                            profilePicBase64!.isNotEmpty)
                        ? MemoryImage(base64Decode(profilePicBase64!))
                        : null,
                    child:
                        (profilePicBase64 == null || profilePicBase64!.isEmpty)
                        ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.collectorName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Past Transaction Reviews',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pastReviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No reviews yet.\nThis is a new collector.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pastReviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final review = pastReviews[index];
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${review['rating']} / 5.0',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    review['category'].toString(),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
