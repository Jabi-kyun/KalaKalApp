import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // ✅ Restored for GPS capture
import '../home_page.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';

// ✅ Comprehensive Legazpi City Barangays for 3km Notification Radius
final List<Map<String, dynamic>> legazpiBarangays = [
  {'name': 'Albay District', 'lat': 13.1485, 'lng': 123.7360},
  {'name': 'EM\'s / Rizal Street', 'lat': 13.1450, 'lng': 123.7320},
  {'name': 'Padre Diaz', 'lat': 13.1420, 'lng': 123.7380},
  {'name': 'Immaculada Concepcion', 'lat': 13.1400, 'lng': 123.7400},
  {'name': 'Estanza', 'lat': 13.1550, 'lng': 123.7550},
  {'name': 'Maoyod', 'lat': 13.1550, 'lng': 123.7450},
  {'name': 'Puro', 'lat': 13.1520, 'lng': 123.7280},
  {'name': 'Sagpon', 'lat': 13.1200, 'lng': 123.7350},
  {'name': 'Tula-tula Grande', 'lat': 13.1600, 'lng': 123.7500},
  {'name': 'Tula-tula Pequeño', 'lat': 13.1580, 'lng': 123.7480},
  {'name': 'Bitano', 'lat': 13.1391, 'lng': 123.7437},
  {'name': 'Cabagñan', 'lat': 13.1250, 'lng': 123.7500},
  {'name': 'Kapantayan', 'lat': 13.1300, 'lng': 123.7600},
  {'name': 'Lapu-lapu', 'lat': 13.1350, 'lng': 123.7650},
  {'name': 'Sabang', 'lat': 13.1380, 'lng': 123.7420},
  {'name': 'Bagong Abre', 'lat': 13.1650, 'lng': 123.7400},
  {'name': 'Cruzada', 'lat': 13.1700, 'lng': 123.7350},
  {'name': 'Dap-dap', 'lat': 13.1680, 'lng': 123.7450},
  {'name': 'Imalnod', 'lat': 13.1720, 'lng': 123.7380},
  {'name': 'Pinaric', 'lat': 13.1750, 'lng': 123.7420},
  {'name': 'Taysan', 'lat': 13.1620, 'lng': 123.7300},
];

class PostListingPage extends StatefulWidget {
  final Map<String, dynamic>? existingListing;
  const PostListingPage({super.key, this.existingListing});

  @override
  State<PostListingPage> createState() => _PostListingPageState();
}

class _PostListingPageState extends State<PostListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Plastic';

  bool _isLoading = false;
  bool _isLocationLoading = false;
  Position? _currentPosition; // ✅ Back to actual GPS Position
  List<String> _imagesBase64 = [];

  final List<String> _categories = [
    'Plastic', 'Metal', 'Paper', 'Glass', 'E-Waste', 'Furniture', 'Others',
  ];
  final ImagePicker _picker = ImagePicker();

  bool get isEditMode => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _selectedCategory = widget.existingListing!['category'] ?? 'Plastic';
      _quantityController.text = widget.existingListing!['quantity'] ?? '';
      _descriptionController.text = widget.existingListing!['description'] ?? '';

      if (widget.existingListing!['images'] != null) {
        _imagesBase64 = List<String>.from(widget.existingListing!['images']);
      } else if (widget.existingListing!['image'] != null) {
        _imagesBase64 = [widget.existingListing!['image']];
      }

      // ✅ Load existing GPS coordinates if in edit mode
      if (widget.existingListing!['location'] != null &&
          widget.existingListing!['location']['latitude'] != null) {
        final loc = widget.existingListing!['location'];
        _currentPosition = Position(
          latitude: loc['latitude'],
          longitude: loc['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, altitudeAccuracy: 0,
          heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
        );
      }
    }
  }

  Future<void> _pickImages() async {
    if (_imagesBase64.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 images allowed'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 15, maxWidth: 500);
      if (images != null) {
        for (var image in images) {
          if (_imagesBase64.length >= 3) break;
          final bytes = await File(image.path).readAsBytes();

          int currentSize = _imagesBase64.fold<int>(0, (sum, img) => sum + base64Decode(img).length);
          if (currentSize + bytes.length > 800 * 1024) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Images too large. Please use fewer photos.'), backgroundColor: Colors.red),
            );
            break;
          }
          setState(() => _imagesBase64.add(base64Encode(bytes)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ RESTORED: Capture Actual GPS Location
  Future<void> _captureLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location in settings ️'), backgroundColor: Colors.red),
        );
        setState(() => _isLocationLoading = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() => _isLocationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location captured 📍'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing location: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ Haversine Formula for 3km Notifications
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

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isEditMode && _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture your location'), backgroundColor: Colors.orange),
      );
      return;
    }

    int totalSize = 0;
    for (var img in _imagesBase64) totalSize += base64Decode(img).length;
    if (totalSize > 950 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total image size too large. Please remove some photos.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // ✅ Use actual GPS coordinates
      final locationMap = {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      };

      if (isEditMode) {
        await FirebaseFirestore.instance.collection('listings').doc(widget.existingListing!['id']).update({
          'category': _selectedCategory,
          'quantity': _quantityController.text.trim(),
          'description': _descriptionController.text.trim(),
          'images': _imagesBase64,
          'location': locationMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing updated successfully! ✅'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        await FirebaseFirestore.instance.collection('listings').add({
          'uid': user.uid, 'householdUid': user.uid,
          'householdName': userDoc.data()?['name'] ?? 'Household',
          'category': _selectedCategory,
          'quantity': _quantityController.text.trim(),
          'description': _descriptionController.text.trim(),
          'location': locationMap,
          'status': 'Active', 'createdAt': FieldValue.serverTimestamp(),
          'bids': [], 'highestBid': 0.0, 'images': _imagesBase64,
        });

        // ✅ Trigger 3km Notification Logic using actual GPS vs Collector's saved area
        final collectorsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'collector')
            .where('homeLocation', isNotEqualTo: null)
            .get();

        for (var doc in collectorsSnapshot.docs) {
          final collectorData = doc.data();
          final homeLoc = collectorData['homeLocation'] as Map<String, dynamic>?;
          if (homeLoc != null) {
            final distance = _calculateDistance(
              _currentPosition!.latitude, _currentPosition!.longitude,
              homeLoc['latitude'], homeLoc['longitude'],
            );

            if (distance <= 3.0) {
              debugPrint('🔔 Collector ${collectorData['name']} is within ${distance.toStringAsFixed(1)}km.');
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted successfully! ♻️'), backgroundColor: Colors.green));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        }
      }
    } catch (e) {
      debugPrint('❌ Error posting listing: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('invalid-argument')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data too large for database. Please use smaller/fewer photos.'), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: KalaKalAppBar(title: isEditMode ? 'Edit Scrap' : 'Post Scrap', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditMode ? 'Update your listing details:' : 'What are you selling?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 16),

              const Text('Photos (Max 3)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagesBase64.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _imagesBase64.length) {
                      if (_imagesBase64.length >= 3) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(width: 120, height: 120, margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_a_photo, size: 30, color: Colors.grey), SizedBox(height: 4),
                            Text('Add Photo', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      );
                    }
                    return Stack(children: [
                      Container(width: 120, height: 120, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(image: DecorationImage(image: MemoryImage(base64Decode(_imagesBase64[index])), fit: BoxFit.cover), borderRadius: BorderRadius.circular(12))),
                      Positioned(top: 4, right: 12, child: GestureDetector(
                        onTap: () => setState(() => _imagesBase64.removeAt(index)),
                        child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16)),
                      )),
                    ]);
                  },
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category, color: Colors.green), filled: true, fillColor: Colors.white),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity (e.g., 5kg)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.scale, color: Colors.green), filled: true, fillColor: Colors.white), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description, color: Colors.green), filled: true, fillColor: Colors.white), validator: (v) => v?.isEmpty == true ? 'Required' : null),

              // ✅ RESTORED: Capture Current Location Button
              const SizedBox(height: 24),
              const Text('Pickup Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isLocationLoading ? null : _captureLocation,
                icon: _isLocationLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.my_location),
                label: Text(
                  _isLocationLoading ? 'Getting...' : (_currentPosition == null ? '📍 Capture Current Location' : '✅ Location Captured'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPosition != null ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_currentPosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 32),
              PrimaryButton(text: isEditMode ? 'UPDATE LISTING' : 'POST LISTING', onPressed: _submitListing, isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}