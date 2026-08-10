import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../home_page.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';

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

  Position? _currentPosition;
  List<String> _imagesBase64 = [];
  bool _isLoading = false;
  bool _isLocationLoading = false;

  final List<String> _categories = [
    'Plastic',
    'Metal',
    'Paper',
    'Glass',
    'E-Waste',
    'Furniture',
    'Others',
  ];
  final ImagePicker _picker = ImagePicker();

  bool get isEditMode => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _selectedCategory = widget.existingListing!['category'] ?? 'Plastic';
      _quantityController.text = widget.existingListing!['quantity'] ?? '';
      _descriptionController.text =
          widget.existingListing!['description'] ?? '';
      // Load existing images if in edit mode
      if (widget.existingListing!['images'] != null) {
        _imagesBase64 = List<String>.from(widget.existingListing!['images']);
      } else if (widget.existingListing!['image'] != null) {
        _imagesBase64 = [
          widget.existingListing!['image'],
        ]; // Fallback for old single image
      }
    }
  }

  // Aggressive compression to prevent Firestore 1MB limit errors
  Future<void> _pickImages() async {
    if (_imagesBase64.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // AGGRESSIVE COMPRESSION: Lower quality and size significantly
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 15, // Drastically reduced from 50
        maxWidth: 500, // Reduced from 800
      );

      if (images != null) {
        for (var image in images) {
          if (_imagesBase64.length >= 3) break; // Enforce limit strictly

          final bytes = await File(image.path).readAsBytes();

          // Safety check: Don't add if it pushes total over 800KB
          int currentSize = _imagesBase64.fold<int>(
            0,
            (sum, img) => sum + base64Decode(img).length,
          );

          if (currentSize + bytes.length > 800 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Images too large. Please use fewer photos.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            break;
          }

          setState(() {
            _imagesBase64.add(base64Encode(bytes));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location in settings ⚙️'),
              backgroundColor: Colors.red,
            ),
          );
        setState(() => _isLocationLoading = false);
        return;
      }
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _isLocationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured 📍'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocationLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isEditMode && _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Pre-submit size check to give a friendly error instead of crashing
    int totalSize = 0;
    for (var img in _imagesBase64) {
      totalSize += base64Decode(img).length;
    }

    if (totalSize > 950 * 1024) {
      // 950KB safe limit
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Total image size too large. Please remove some photos.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      if (isEditMode) {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.existingListing!['id'])
            .update({
              'category': _selectedCategory,
              'quantity': _quantityController.text.trim(),
              'description': _descriptionController.text.trim(),
              'images': _imagesBase64,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing updated successfully! ✅'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        await FirebaseFirestore.instance.collection('listings').add({
          'uid': user.uid,
          'householdUid': user.uid,
          'householdName': userDoc.data()?['name'] ?? 'Household',
          'category': _selectedCategory,
          'quantity': _quantityController.text.trim(),
          'description': _descriptionController.text.trim(),
          'location': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          },
          'status': 'Active',
          'createdAt': FieldValue.serverTimestamp(),
          'bids': [],
          'highestBid': 0.0,
          'images': _imagesBase64,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Posted successfully! ♻️'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error posting listing: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('invalid-argument')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Data too large for database. Please use smaller/fewer photos.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
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
      appBar: KalaKalAppBar(
        title: isEditMode ? 'Edit Scrap' : 'Post Scrap',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditMode
                    ? 'Update your listing details:'
                    : 'What are you selling?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),

              // Horizontal Scrollable Image List
              const Text(
                'Photos (Max 3)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagesBase64.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _imagesBase64.length) {
                      if (_imagesBase64.length >= 3)
                        return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 30,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Display existing image with a delete button
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: MemoryImage(
                                base64Decode(_imagesBase64[index]),
                              ),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _imagesBase64.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (e.g., 5kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              if (!isEditMode) ...[
                const SizedBox(height: 24),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLocationLoading ? null : _getLocation,
                  icon: _isLocationLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isLocationLoading
                        ? 'Getting...'
                        : (_currentPosition == null
                              ? ' Capture Location'
                              : '✅ Captured'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPosition != null
                        ? Colors.green
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                text: isEditMode ? 'UPDATE LISTING' : 'POST LISTING',
                onPressed: _submitListing,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
