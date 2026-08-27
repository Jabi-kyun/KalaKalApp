import 'dart:convert';
import 'dart:math' as math; // ✅ Added for Haversine distance formula
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // ✅ Added for GPS location
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/top_snackbar.dart';
import 'place_bid_page.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

class NearbyListingsPage extends StatefulWidget {
  const NearbyListingsPage({super.key});

  @override
  State<NearbyListingsPage> createState() => _NearbyListingsPageState();
}

class _NearbyListingsPageState extends State<NearbyListingsPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the loading state and the filtered list of nearby listings
  // ==========================================================================

  bool isLoading = true;
  List<Map<String, dynamic>> listings = [];

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically fetch and filter nearby listings when the page opens
    _fetchActiveListings();
  }

  // ==========================================================================
  // 3. HELPER & DATA FETCHING FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR CALCULATING EXACT DISTANCE.
  /// It uses the Haversine formula to calculate the precise distance in kilometers
  /// between two GPS coordinates (the collector's current location and the listing's location).
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371; // Earth's radius in km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// THESE CODES ARE FOR FETCHING AND STRICTLY FILTERING LISTINGS BY 1KM RADIUS.
  /// Since Firestore doesn't natively support complex geospatial distance queries,
  /// this function: 1) Gets the collector's live GPS, 2) Fetches ALL active listings,
  /// and 3) Filters them locally in Dart using the Haversine formula to ensure
  /// ONLY listings within exactly 1.0 km are displayed to the collector.
  Future<void> _fetchActiveListings() async {
    setState(() => isLoading = true);
    try {
      // Step 1: Get the collector's current live GPS location
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Step 2: Fetch ALL active listings from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .orderBy('createdAt', descending: true)
          .get();

      // Step 3: Filter them locally based on the STRICT 1km rule
      List<Map<String, dynamic>> nearbyListings = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // Ensure the listing has valid saved coordinates before calculating
        if (data['location'] != null &&
            data['location']['latitude'] != null &&
            data['location']['longitude'] != null) {
          double distance = _calculateDistance(
            currentPosition.latitude,
            currentPosition.longitude,
            data['location']['latitude'],
            data['location']['longitude'],
          );

          // ✅ STRICT 1KM FILTER: Discard anything further than 1.0 km
          if (distance <= 1.0) {
            data['distance'] =
                distance; // Save distance to display on the UI card
            nearbyListings.add(data);
          }
        }
      }

      if (mounted) {
        setState(() {
          listings = nearbyListings;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching active listings: $e');
      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Failed to load listings: $e',
          backgroundColor: Colors.red,
        );
        setState(() => isLoading = false);
      }
    }
  }

  // ==========================================================================
  // 4. UI COMPONENT FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR THE FULL-SCREEN IMAGE GALLERY.
  /// It opens a dark-themed, swipeable, pinch-to-zoom viewer for the listing's photos.
  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text('${initialIndex + 1} / ${images.length}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {}); // Update the counter text on swipe
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Image.memory(
                      base64Decode(images[index]),
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              // Image counter overlay at the bottom
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${initialIndex + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// THESE CODES ARE FOR THE DRAGGABLE LISTING DETAILS BOTTOM SHEET.
  /// It displays the full listing information, images, and the "Place Bid" action button.
  void _showListingBottomSheet(Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Horizontal Image Slider
                  if (listing['images'] != null &&
                      (listing['images'] as List).isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        controller: scrollController,
                        itemCount: (listing['images'] as List).length,
                        itemBuilder: (context, imgIndex) {
                          return GestureDetector(
                            onTap: () => _showImageGallery(
                              List<String>.from(listing['images']),
                              imgIndex,
                            ),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: MemoryImage(
                                    base64Decode(
                                      (listing['images'] as List)[imgIndex],
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.green,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Listing Details
                  Text(
                    listing['category'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Household: ${listing['householdName'] ?? 'Anonymous'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Quantity: ${listing['quantity']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing['description'] ?? 'No description',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Place Bid Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaceBidPage(
                              listingId: listing['id'],
                              category: listing['category'] ?? 'Unknown',
                              quantity: listing['quantity'] ?? '',
                              description:
                                  listing['description'] ?? 'No description',
                              householdName:
                                  listing['householdName'] ??
                                  'Anonymous Household',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.gavel, color: Colors.white),
                      label: const Text(
                        'PLACE BID',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // 5. UI BUILD METHOD
  // This code renders the visual layout of the Nearby Listings page
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: KalaKalAppBar(
        title: 'Nearby Listings',
        showBackButton: true,
        actions: [
          // Badge showing the total count of filtered nearby listings
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${listings.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading
          // Show loading spinner while fetching and filtering data
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          // Show empty state specifically mentioning the 1km radius
          : listings.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No listings within 1km.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Households haven\'t posted any scraps nearby yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          // Show the scrollable list of strictly filtered listings
          : RefreshIndicator(
              onRefresh: _fetchActiveListings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final item = listings[index];
                  final date = item['createdAt'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((item['createdAt'] as Timestamp).toDate())
                      : 'Unknown Date';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Horizontal Image Slider on the Card
                        if (item['images'] != null &&
                            (item['images'] as List).isNotEmpty)
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (item['images'] as List).length,
                              itemBuilder: (context, imgIndex) {
                                return GestureDetector(
                                  onTap: () => _showImageGallery(
                                    List<String>.from(item['images']),
                                    imgIndex,
                                  ),
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width - 64,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image.memory(
                                        base64Decode(
                                          (item['images'] as List)[imgIndex],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.green,
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Category Chip and Exact Distance
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item['category'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // ✅ Displays the exact calculated distance
                                  Text(
                                    '📍 ${(item['distance'] as double).toStringAsFixed(2)} km',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Listing Details
                              Text(
                                item['householdName'] ?? 'Anonymous Household',
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
                                item['description'] ??
                                    'No description provided.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 12),

                              // Bottom Row: Date and Place Bid Button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showListingBottomSheet(item),
                                    icon: const Icon(
                                      Icons.gavel,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'PLACE BID',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
