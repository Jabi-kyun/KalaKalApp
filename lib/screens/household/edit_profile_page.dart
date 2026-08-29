import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// CONSTANTS & DATA
// ============================================================================

// COMPREHENSIVE LEGAZPI CITY BARANGAYS WITH GPS COORDINATES FOR THE NOTIFICATION RADIUS.
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

// THIS CLASS DEFINES THE EDIT PROFILE PAGE FOR HOUSEHOLDS.
// IT ALLOWS USERS TO UPDATE THEIR PERSONAL INFORMATION, PROFILE PICTURE,
// AND NOTIFICATION AREA FOR THE BIDDING SYSTEM.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE FORM CONTROLLERS, LOADING STATES, AND PROFILE DATA.
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
    // AUTOMATICALLY LOAD THE USER'S EXISTING PROFILE DATA WHEN THE PAGE OPENS.
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    // CLEANS UP MEMORY BY DISPOSING TEXT CONTROLLERS WHEN THE PAGE IS CLOSED.
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. DATA FETCHING & HELPER FUNCTIONS
  // ==========================================================================

  /// THIS FUNCTION LOADS THE EXISTING PROFILE DATA.
  /// IT FETCHES THE CURRENT USER'S DOCUMENT FROM FIRESTORE AND PRE-FILLS THE
  /// TEXT FIELDS, DATE PICKER, PROFILE PICTURE, AND SELECTED NOTIFICATION AREA.
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

          // LOAD EXISTING LEGAZPI AREA IF IT WAS PREVIOUSLY SAVED
          if (data['homeLocation'] != null &&
              data['homeLocation']['areaName'] != null) {
            _selectedArea = data['homeLocation']['areaName'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  /// THIS FUNCTION HANDLES PICKING A NEW PROFILE PICTURE.
  /// IT OPENS THE DEVICE'S IMAGE GALLERY, COMPRESSES THE IMAGE (QUALITY: 50),
  /// AND SAVES THE FILE PATH TO BE CONVERTED TO BASE64 LATER.
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

  /// THIS FUNCTION CONVERTS THE SELECTED IMAGE TO BASE64.
  /// FIRESTORE REQUIRES IMAGES TO BE STORED AS STRINGS (BASE64) FOR THIS IMPLEMENTATION.
  Future<String?> _convertImageToBase64() async {
    if (_imageFile == null) return _currentProfileBase64;
    try {
      final bytes = await _imageFile!.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  /// THIS FUNCTION HANDLES SELECTING A BIRTHDAY.
  /// IT OPENS A DATE PICKER DIALOG AND FORMATS THE SELECTED DATE TO MM/DD/YYYY.
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

  /// THIS FUNCTION SAVES THE UPDATED PROFILE TO FIRESTORE.
  /// IT VALIDATES THE FORM, CONVERTS THE NEW IMAGE (IF ANY), MAPS THE SELECTED
  /// BARANGAY TO ITS GPS COORDINATES, AND UPDATES THE USER'S DOCUMENT.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profileBase64 = await _convertImageToBase64();

      // GET GPS COORDINATES FROM THE SELECTED AREA DROPDOWN
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

      // UPDATE THE USER DOCUMENT IN FIRESTORE
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'birthday': _selectedDate != null
              ? Timestamp.fromDate(_selectedDate!)
              : FieldValue.delete(),

          // FIXED SYNTAX: ONLY UPDATE PROFILEPIC IF A NEW ONE WAS SELECTED
          if (profileBase64 != null) 'profilePic': profileBase64,

          // SAVE OR DELETE HOMELOCATION BASED ON DROPDOWN SELECTION
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
        message: 'Profile updated successfully!',
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
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE HOUSEHOLD PROFILE EDIT SCREEN.
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
              // --- PROFILE PICTURE SECTION ---
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

              // --- NAME FIELD ---
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

              // --- EMAIL FIELD (READ ONLY) ---
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

              // --- PHONE NUMBER FIELD ---
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

              // --- BIRTHDAY FIELD ---
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

              // --- ADDRESS FIELD ---
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

              // --- NOTIFICATION AREA DROPDOWN ---
              const Text(
                'Set Notification Area (Legazpi)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Collectors within 1km of this area will be notified when you post.', // UPDATED TO MATCH 1KM LOGIC
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

              // --- SAVE BUTTON ---
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
