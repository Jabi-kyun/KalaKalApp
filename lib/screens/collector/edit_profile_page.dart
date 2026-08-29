import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart';

// ============================================================================
// WIDGET CLASS
// ============================================================================

// THIS CLASS DEFINES THE EDIT PROFILE PAGE FOR COLLECTORS.
// IT ALLOWS COLLECTORS TO UPDATE THEIR PERSONAL INFORMATION, VEHICLE DETAILS,
// SERVICE AREA, AND PROFILE PICTURE.
class EditCollectorProfilePage extends StatefulWidget {
  const EditCollectorProfilePage({super.key});

  @override
  State<EditCollectorProfilePage> createState() =>
      _EditCollectorProfilePageState();
}

class _EditCollectorProfilePageState extends State<EditCollectorProfilePage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // ==========================================================================

  // THESE HOLD THE TEXT CONTROLLERS, IMAGE DATA, AND LOADING STATES FOR THE FORM.
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _profilePicBase64; // STORES THE PROFILE PICTURE AS A BASE64 STRING
  bool _isLoading = true; // SHOWS A LOADING SPINNER WHILE FETCHING INITIAL DATA
  bool _isSaving = false; // SHOWS A LOADING SPINNER ON THE SAVE BUTTON

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // AUTOMATICALLY LOAD THE COLLECTOR'S EXISTING PROFILE DATA WHEN THE PAGE OPENS.
    _loadProfile();
  }

  @override
  void dispose() {
    // CLEANS UP MEMORY BY DISPOSING TEXT CONTROLLERS WHEN THE PAGE IS CLOSED.
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THIS FUNCTION LOADS THE EXISTING PROFILE DATA.
  /// IT FETCHES THE CURRENT USER'S DOCUMENT FROM FIRESTORE AND PRE-FILLS THE
  /// TEXT FIELDS AND PROFILE PICTURE SO THE COLLECTOR CAN SEE AND EDIT THEIR CURRENT INFO.
  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _nameController.text = doc.data()?['name'] ?? '';
          _phoneController.text = doc.data()?['phone'] ?? '';
          _vehicleController.text = doc.data()?['vehicleType'] ?? '';
          _serviceAreaController.text = doc.data()?['serviceArea'] ?? '';
          _profilePicBase64 = doc.data()?['profilePic'];
          _isLoading = false; // HIDE LOADING SPINNER ONCE DATA IS LOADED
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  /// THIS FUNCTION HANDLES PICKING AND ENCODING A NEW PROFILE PICTURE.
  /// IT OPENS THE DEVICE'S IMAGE GALLERY, COMPRESSES THE IMAGE (QUALITY: 50),
  /// READS IT AS BYTES, AND CONVERTS IT TO A BASE64 STRING TO BE SAVED IN FIRESTORE.
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _profilePicBase64 = base64Encode(bytes);
      });
    }
  }

  /// THIS FUNCTION SAVES THE UPDATED PROFILE TO FIRESTORE.
  /// IT VALIDATES THAT THE NAME ISN'T EMPTY, UPDATES THE USER'S DOCUMENT IN THE
  /// DATABASE WITH THE NEW VALUES, SHOWS A SUCCESS TOPSNACKBAR, AND RETURNS TO THE PREVIOUS SCREEN.
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      TopSnackBar.show(
        context,
        message: 'Name cannot be empty',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // UPDATE ONLY THE SPECIFIC FIELDS IN THE USER'S FIRESTORE DOCUMENT
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'vehicleType': _vehicleController.text.trim(),
            'serviceArea': _serviceAreaController.text.trim(),
            'profilePic': _profilePicBase64,
          });

      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Profile updated successfully!',
          backgroundColor: Colors.green,
        );
        // RETURN 'TRUE' TO TELL THE PREVIOUS SCREEN (HOMEPAGE) TO REFRESH ITS DATA
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'Error saving profile: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================================================
  // 4. UI BUILD METHOD
  // ==========================================================================

  /// THIS METHOD RENDERS THE VISUAL LAYOUT OF THE COLLECTOR PROFILE EDIT SCREEN.
  @override
  Widget build(BuildContext context) {
    // SHOW A LOADING SPINNER WHILE THE INITIAL PROFILE DATA IS BEING FETCHED
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F7F3),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: 'Edit Profile', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- PROFILE PICTURE SECTION ---
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.green.shade100,
                    // DISPLAY THE BASE64 IMAGE IF IT EXISTS, OTHERWISE SHOW A DEFAULT TRUCK ICON
                    backgroundImage: _profilePicBase64 != null
                        ? MemoryImage(base64Decode(_profilePicBase64!))
                        : null,
                    child: _profilePicBase64 == null
                        ? Icon(
                            Icons.local_shipping,
                            size: 60,
                            color: Colors.green.shade800,
                          )
                        : null,
                  ),
                  // CAMERA ICON OVERLAY TO INDICATE THE PICTURE IS CLICKABLE
                  Container(
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to change photo',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // --- NAME FIELD ---
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // --- PHONE FIELD ---
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // --- VEHICLE TYPE FIELD ---
            TextField(
              controller: _vehicleController,
              decoration: InputDecoration(
                labelText: 'Vehicle Type (e.g., Tricycle, Multicab)',
                prefixIcon: const Icon(
                  Icons.directions_car,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // --- SERVICE AREA FIELD ---
            TextField(
              controller: _serviceAreaController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Service Area / Preferred Barangays',
                prefixIcon: const Icon(Icons.map, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // --- SAVE BUTTON ---
            PrimaryButton(
              text: 'SAVE CHANGES',
              onPressed: _saveProfile,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
