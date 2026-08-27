import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// CONSTANTS & DATA
// ============================================================================

// Comprehensive Legazpi City Barangays with GPS coordinates for the Notification Radius
final List<Map<String, dynamic>> legazpiBarangays = [
  {'name': 'Select a Barangay', 'lat': 0.0, 'lng': 0.0},
  // Poblacion / City Proper
  {'name': 'Albay District', 'lat': 13.1485, 'lng': 123.7360},
  {'name': 'EM\'s / Rizal Street', 'lat': 13.1450, 'lng': 123.7320},
  {'name': 'Padre Diaz', 'lat': 13.1420, 'lng': 123.7380},
  {'name': 'Immaculada Concepcion', 'lat': 13.1400, 'lng': 123.7400},
  // East Legazpi
  {'name': 'Estanza', 'lat': 13.1550, 'lng': 123.7550},
  {'name': 'Maoyod', 'lat': 13.1550, 'lng': 123.7450},
  {'name': 'Puro', 'lat': 13.1520, 'lng': 123.7280},
  {'name': 'Sagpon', 'lat': 13.1200, 'lng': 123.7350},
  {'name': 'Tula-tula Grande', 'lat': 13.1600, 'lng': 123.7500},
  {'name': 'Tula-tula Pequeño', 'lat': 13.1580, 'lng': 123.7480},
  // West / Coastal Legazpi
  {'name': 'Bitano', 'lat': 13.1391, 'lng': 123.7437},
  {'name': 'Cabagñan', 'lat': 13.1250, 'lng': 123.7500},
  {'name': 'Kapantayan', 'lat': 13.1300, 'lng': 123.7600},
  {'name': 'Lapu-lapu', 'lat': 13.1350, 'lng': 123.7650},
  {'name': 'Rizal Street Extension', 'lat': 13.1430, 'lng': 123.7300},
  {'name': 'Sabang', 'lat': 13.1380, 'lng': 123.7420},
  // North / Upland Legazpi
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

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the form controllers, loading states, and profile data
  // ==========================================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdayController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedDate;
  File? _imageFile;
  String? _currentProfileBase64;
  String? _selectedArea;

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically load the user's existing profile data when the page opens
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    // Cleans up memory by disposing text controllers when the page is closed
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. DATA FETCHING & HELPER FUNCTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR LOADING THE EXISTING PROFILE DATA.
  /// It fetches the current user's document from Firestore and pre-fills the
  /// text fields, date picker, profile picture, and selected notification area.
  Future<void> _loadCurrentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _currentProfileBase64 = data['profilePic'];

          if (data['birthday'] != null) {
            _selectedDate = (data['birthday'] as Timestamp).toDate();
            _birthdayController.text = DateFormat(
              'MM/dd/yyyy',
            ).format(_selectedDate!);
          }

          // Load existing Legazpi area if it was previously saved
          if (data['homeLocation'] != null &&
              data['homeLocation']['areaName'] != null) {
            _selectedArea = data['homeLocation']['areaName'];
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
    }
  }

  /// THESE CODES ARE FOR PICKING A NEW PROFILE PICTURE.
  /// It opens the device's image gallery, compresses the image (quality: 50),
  /// and saves the file path to be converted to Base64 later.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  /// THESE CODES ARE FOR CONVERTING THE IMAGE TO BASE64.
  /// Firestore requires images to be stored as strings (Base64) for this implementation.
  Future<String?> _convertImageToBase64() async {
    if (_imageFile == null) return _currentProfileBase64;
    try {
      final bytes = await _imageFile!.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('❌ Error converting image: $e');
      return null;
    }
  }

  /// THESE CODES ARE FOR SELECTING A BIRTHDAY.
  /// It opens a date picker dialog and formats the selected date to MM/dd/yyyy.
  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // ==========================================================================
  // 4. USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR SAVING THE UPDATED PROFILE TO FIRESTORE.
  /// It validates the form, converts the new image (if any), maps the selected
  /// barangay to its GPS coordinates, and updates the user's document.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profileBase64 = await _convertImageToBase64();

      // Get GPS coordinates from the selected area dropdown
      Map<String, dynamic>? homeLocationMap;
      if (_selectedArea != null && _selectedArea != 'Select a Barangay') {
        final areaData = legazpiBarangays.firstWhere(
          (a) => a['name'] == _selectedArea,
        );
        homeLocationMap = {
          'latitude': areaData['lat'],
          'longitude': areaData['lng'],
          'areaName': _selectedArea,
        };
      }

      // Update the user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'birthday': _selectedDate != null
              ? Timestamp.fromDate(_selectedDate!)
              : FieldValue.delete(),

          // ✅ Fixed syntax: Only update profilePic if a new one was selected
          if (profileBase64 != null) 'profilePic': profileBase64,

          // ✅ Save or delete homeLocation based on dropdown selection
          if (homeLocationMap != null)
            'homeLocation': homeLocationMap
          else
            'homeLocation': FieldValue.delete(),

          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      TopSnackBar.show(
        context,
        message: 'Profile updated successfully! ✅',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,
        message: 'Error updating profile: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // 5. UI BUILD METHOD
  // This code renders the visual layout of the Household Profile Edit screen
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Edit Profile', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Profile Picture Section ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentProfileBase64 != null
                                ? MemoryImage(
                                    base64Decode(_currentProfileBase64!),
                                  )
                                : null),
                      child: _imageFile == null && _currentProfileBase64 == null
                          ? Text(
                              (_nameController.text.isNotEmpty
                                      ? _nameController.text[0]
                                      : '?')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- Name Field ---
              const Text(
                'Full Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- Email Field (Read Only) ---
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'N/A',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email cannot be changed.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // --- Phone Number Field ---
              const Text(
                'Contact Number',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.phone, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Phone is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- Birthday Field ---
              const Text(
                'Birthday',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _selectBirthday,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.cake, color: Colors.green),
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Birthday is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- Address Field ---
              const Text(
                'Complete Address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.home, color: Colors.green),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- Notification Area Dropdown ---
              const Text(
                'Set Notification Area (Legazpi)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Collectors within 1km of this area will be notified when you post.', // ✅ Updated to match 1km logic
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedArea,
                decoration: InputDecoration(
                  labelText: 'Select Barangay / Area',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.location_city, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: legazpiBarangays.map((area) {
                  return DropdownMenuItem(
                    value: area['name'] as String,
                    child: Text(area['name'] as String),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedArea = value),
                validator: (v) => v == null || v == 'Select a Barangay'
                    ? 'Please select a barangay'
                    : null,
              ),

              const SizedBox(height: 30),

              // --- Save Button ---
              PrimaryButton(
                text: _isLoading ? 'Saving...' : 'SAVE CHANGES',
                onPressed: _saveProfile,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
