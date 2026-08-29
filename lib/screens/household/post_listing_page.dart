import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/top_snackbar.dart';
import '../home_page.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';

// ============================================================================
// CONSTANTS & DATA
// ============================================================================

// LIST OF LEGAZPI CITY BARANGAYS WITH THEIR EXACT GPS COORDINATES.
// THIS IS USED FOR THE DROPDOWN IN THE HOUSEHOLD PROFILE SETTINGS.
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

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE POST LISTING PAGE FOR HOUSEHOLDS.
// IT ALLOWS USERS TO CREATE NEW SCRAP LISTINGS OR EDIT EXISTING ONES,
// INCLUDING CAPTURING LOCATION AND UPLOADING IMAGES.
class PostListingPage extends StatefulWidget {
  final Map<String, dynamic>? existingListing;
  const PostListingPage({super.key, this.existingListing});

  @override
  State<PostListingPage> createState() => _PostListingPageState();
}

class _PostListingPageState extends State<PostListingPage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE FORM DATA, LOADING STATES, CURRENT LOCATION, AND UPLOADED IMAGES IN BASE64 FORMAT.
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Plastic';
  bool _isLoading = false;
  bool _isLocationLoading = false;
  Position? _currentPosition;
  List<String> _imagesBase64 = [];

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

  // CHECKS IF THE USER IS EDITING AN EXISTING POST OR CREATING A NEW ONE
  bool get isEditMode => widget.existingListing != null;

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // IF EDITING, PRE-FILL THE FORM WITH THE EXISTING LISTING'S DATA
    if (isEditMode) {
      _selectedCategory = widget.existingListing!['category'] ?? 'Plastic';
      _quantityController.text = widget.existingListing!['quantity'] ?? '';
      _descriptionController.text =
          widget.existingListing!['description'] ?? '';

      if (widget.existingListing!['images'] != null) {
        _imagesBase64 = List<String>.from(widget.existingListing!['images']);
      } else if (widget.existingListing!['image'] != null) {
        _imagesBase64 = [widget.existingListing!['image']];
      }

      // LOAD EXISTING GPS COORDINATES IF IN EDIT MODE
      if (widget.existingListing!['location'] != null &&
          widget.existingListing!['location']['latitude'] != null) {
        final loc = widget.existingListing!['location'];
        _currentPosition = Position(
          latitude: loc['latitude'],
          longitude: loc['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    }
  }

  @override
  void dispose() {
    // CLEANS UP MEMORY BY DISPOSING CONTROLLERS WHEN THE PAGE IS CLOSED
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. HELPER FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION USES THE HAVERSINE FORMULA TO CALCULATE THE EXACT DISTANCE
  /// IN KILOMETERS BETWEEN TWO GPS COORDINATES. IT IS USED TO FILTER COLLECTORS
  /// WITHIN A STRICT 1KM RADIUS FOR PUSH NOTIFICATIONS.
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371; // EARTH'S RADIUS IN KM
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

  // ==========================================================================
  // 4. USER ACTION FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION HANDLES PICKING IMAGES FROM THE GALLERY.
  /// IT ENFORCES A MAXIMUM LIMIT OF 3 IMAGES AND CHECKS THE TOTAL FILE SIZE
  /// TO PREVENT FIRESTORE DOCUMENT SIZE ERRORS.
  Future<void> _pickImages() async {
    if (_imagesBase64.length >= 3) {
      TopSnackBar.show(
        context,
        message: 'Maximum 3 images allowed',
        backgroundColor: Colors.orange,
      );
      return;
    }
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 15,
        maxWidth: 500,
      );
      for (var image in images) {
        if (_imagesBase64.length >= 3) break;
        final bytes = await File(image.path).readAsBytes();
        int currentSize = _imagesBase64.fold<int>(
          0,
          (sum, img) => sum + base64Decode(img).length,
        );

        if (currentSize + bytes.length > 800 * 1024) {
          if (mounted)
            TopSnackBar.show(
              context,
              message: 'Images too large. Please use fewer photos.',
              backgroundColor: Colors.red,
            );
          break;
        }
        setState(() => _imagesBase64.add(base64Encode(bytes)));
      }
    } catch (e) {
      if (mounted)
        TopSnackBar.show(
          context,
          message: 'Error picking images: $e',
          backgroundColor: Colors.red,
        );
    }
  }

  /// THIS FUNCTION REQUESTS GPS PERMISSIONS AND CAPTURES THE USER'S CURRENT LOCATION.
  /// IT HANDLES DENIED PERMISSIONS GRACEFULLY AND PROMPTS THE USER TO ENABLE LOCATION SERVICES.
  Future<void> _captureLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          TopSnackBar.show(
            context,
            message: 'Enable location in settings',
            backgroundColor: Colors.red,
          );
        setState(() => _isLocationLoading = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() => _isLocationLoading = false);
        TopSnackBar.show(
          context,
          message: 'Location captured',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocationLoading = false);
        TopSnackBar.show(
          context,
          message: 'Error capturing location: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// THIS FUNCTION HANDLES THE PUSH NOTIFICATION LOGIC.
  /// IT QUERIES ALL COLLECTORS, CALCULATES THE DISTANCE TO EACH USING THE HAVERSINE FORMULA,
  /// FILTERS STRICTLY BY A 1KM RADIUS, AND SENDS AN HTTP REQUEST TO THE ONESIGNAL API
  /// TO TRIGGER PUSH NOTIFICATIONS TO NEARBY COLLECTORS.
  Future<void> _sendNearbyNotifications(String householdName) async {
    if (_currentPosition == null) return;

    try {
      // 1. GET ALL COLLECTORS WHO HAVE A ONESIGNAL ID AND A SAVED HOME LOCATION
      final collectorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'collector')
          .where('onesignalId', isNotEqualTo: null)
          .where('homeLocation', isNotEqualTo: null)
          .get();

      List<String> targetPlayerIds = [];

      // 2. LOOP THROUGH COLLECTORS AND CALCULATE DISTANCE
      for (var doc in collectorsSnapshot.docs) {
        final collectorData = doc.data();
        final homeLoc = collectorData['homeLocation'] as Map<String, dynamic>?;

        if (homeLoc != null && homeLoc['latitude'] != null) {
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            homeLoc['latitude'],
            homeLoc['longitude'],
          );

          // 3. STRICT 1KM RADIUS FILTER: ONLY ADD TO NOTIFICATION LIST IF WITHIN 1KM
          if (distance <= 1.0) {
            targetPlayerIds.add(collectorData['onesignalId']);
            debugPrint(
              'Collector ${collectorData['name']} is within ${distance.toStringAsFixed(1)}km.',
            );
          }
        }
      }

      // 4. SEND THE ACTUAL HTTP REQUEST TO ONESIGNAL API
      if (targetPlayerIds.isNotEmpty) {
        final String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
        final String oneSignalRestApiKey =
            dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

        if (oneSignalAppId.isEmpty || oneSignalRestApiKey.isEmpty) {
          debugPrint(
            'OneSignal keys missing from .env file. Notification skipped.',
          );
          return;
        }

        final url = Uri.parse('https://onesignal.com/api/v1/notifications');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic $oneSignalRestApiKey',
          },
          body: jsonEncode({
            'app_id': oneSignalAppId,
            'include_player_ids': targetPlayerIds,
            'headings': {'en': 'New Scrap Nearby!'},
            'contents': {
              'en':
                  '$householdName posted $_selectedCategory (${_quantityController.text}) nearby!',
            },
          }),
        );

        if (response.statusCode == 200) {
          debugPrint(
            'Notifications sent successfully to ${targetPlayerIds.length} collectors!',
          );
        } else {
          debugPrint('Failed to send notification: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// THIS FUNCTION HANDLES THE FINAL SUBMISSION OF THE LISTING.
  /// IT VALIDATES THE FORM, CHECKS IMAGE SIZE LIMITS, SAVES THE DATA TO FIRESTORE,
  /// AND TRIGGERS THE NEARBY NOTIFICATION FUNCTION FOR NEW LISTINGS.
  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isEditMode && _currentPosition == null) {
      TopSnackBar.show(
        context,
        message: 'Please capture your location',
        backgroundColor: Colors.orange,
      );
      return;
    }

    // CHECK TOTAL IMAGE SIZE LIMIT (MAX 950KB TO PREVENT FIRESTORE DOCUMENT SIZE ERRORS)
    int totalSize = 0;
    for (var img in _imagesBase64) totalSize += base64Decode(img).length;
    if (totalSize > 950 * 1024) {
      TopSnackBar.show(
        context,
        message: 'Total image size too large. Please remove some photos.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final locationMap = {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      };

      if (isEditMode) {
        // UPDATE EXISTING LISTING IN FIRESTORE
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.existingListing!['id'])
            .update({
              'category': _selectedCategory,
              'quantity': _quantityController.text.trim(),
              'description': _descriptionController.text.trim(),
              'images': _imagesBase64,
              'location': locationMap,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Listing updated successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.pop(context);
        }
      } else {
        // CREATE NEW LISTING IN FIRESTORE
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final householdName = userDoc.data()?['name'] ?? 'A Household';

        await FirebaseFirestore.instance.collection('listings').add({
          'uid': user.uid,
          'householdUid': user.uid,
          'householdName': householdName,
          'category': _selectedCategory,
          'quantity': _quantityController.text.trim(),
          'description': _descriptionController.text.trim(),
          'location': locationMap,
          'status': 'Active',
          'createdAt': FieldValue.serverTimestamp(),
          'bids': [],
          'highestBid': 0.0,
          'images': _imagesBase64,
        });

        // TRIGGER THE PUSH NOTIFICATION FUNCTION DEFINED ABOVE
        await _sendNearbyNotifications(householdName);

        if (mounted) {
          TopSnackBar.show(
            context,
            message: 'Posted successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error posting listing: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('invalid-argument')) {
          TopSnackBar.show(
            context,
            message:
                'Data too large for database. Please use smaller/fewer photos.',
            backgroundColor: Colors.red,
          );
        } else {
          TopSnackBar.show(
            context,
            message: 'Error: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // 5. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE SCREEN.
  /// IT INCLUDES THE FORM, IMAGE PICKER, INPUT FIELDS, LOCATION CAPTURE BUTTON,
  /// AND THE SUBMIT BUTTON.
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

              // --- IMAGE PICKER UI ---
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
                            border: Border.all(color: Colors.grey.shade400),
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

              // --- CATEGORY DROPDOWN UI ---
              DropdownButtonFormField<String>(
                value: _selectedCategory,
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

              // --- QUANTITY INPUT UI ---
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

              // --- DESCRIPTION INPUT UI ---
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
              const SizedBox(height: 24),

              // --- LOCATION CAPTURE UI ---
              const Text(
                'Pickup Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isLocationLoading ? null : _captureLocation,
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
                            ? ' Capture Current Location'
                            : 'Location Captured'),
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

              const SizedBox(height: 32),

              // --- SUBMIT BUTTON UI ---
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
