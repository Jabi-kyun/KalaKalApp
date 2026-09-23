import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import 'InAppRoutePage.dart';
import 'place_bid_page.dart';

class CollectorMapHomeScreen extends StatefulWidget {
  const CollectorMapHomeScreen({super.key});

  @override
  State<CollectorMapHomeScreen> createState() => _CollectorMapHomeScreenState();
}

class _CollectorMapHomeScreenState extends State<CollectorMapHomeScreen> {
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyListings = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initMapAndFetchListings();
  }

  Future<void> _initMapAndFetchListings() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'Active')
          .get();

      final nearby = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final loc = data['location'] as Map<String, dynamic>?;
        
        if (loc != null && loc['latitude'] != null) {
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            loc['latitude'],
            loc['longitude'],
          );

          if (distance <= 1.0) {
            data['id'] = doc.id;
            data['distance'] = distance;
            nearby.add(data);
          }
        }
      }

      setState(() {
        _nearbyListings = nearby;
        _isLoading = false;
      });

      if (_currentPosition != null) {
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        );
      }
    } catch (e) {
      debugPrint('❌ Map init error: $e');
      setState(() => _isLoading = false);
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime postTime;
    if (timestamp is Timestamp) {
      postTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        postTime = DateTime.parse(timestamp);
      } catch (e) {
        return '';
      }
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(postTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    
    return DateFormat('MMM d').format(postTime);
  }

  void _showListingBottomSheet(Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
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

                // Images (if any)
                if (listing['images'] != null && (listing['images'] as List).isNotEmpty)
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (listing['images'] as List).length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: MediaQuery.of(context).size.width - 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: MemoryImage(
                                base64.decode((listing['images'] as List)[index]),
                              ),
                              fit: BoxFit.cover,
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
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.green),
                    ),
                  ),

                const SizedBox(height: 16),

                // Category & Distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing['category'] ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '📍 ${(listing['distance'] as double).toStringAsFixed(2)} km',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Household Name
                Text(
                  listing['householdName'] ?? 'Anonymous Household',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

                const SizedBox(height: 8),

                // Quantity
                Text(
                  'Quantity: ${listing['quantity']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  listing['description'] ?? 'No description provided',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),

                // Time Posted
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeAgo(listing['createdAt']),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Place Bid Button ✅ FIXED NAVIGATION HERE
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                          MaterialPageRoute(
                            builder: (_) => PlaceBidPage(
                              listingId: listing['id'],
                              category: listing['category'] ?? 'Unknown',
                              quantity: listing['quantity'] ?? '',
                              description: listing['description'] ?? 'No description',
                              householdName: listing['householdName'] ?? 'Anonymous Household',
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
                        fontSize: 16,
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(13.1391, 123.7437),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kalakal.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
                          ),
                        ..._nearbyListings.map((listing) {
                          final loc = listing['location'] as Map<String, dynamic>;
                          return Marker(
                            point: LatLng(loc['latitude'], loc['longitude']),
                            child: GestureDetector(
                              onTap: () => _showListingBottomSheet(listing),
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                if (_nearbyListings.isEmpty && !_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.white),
                            const SizedBox(height: 16),
                            const Text('No pickups within 1km', 
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Move closer to households or wait for new posts',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}