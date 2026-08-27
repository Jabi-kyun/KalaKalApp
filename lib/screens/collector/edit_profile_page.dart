import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/top_snackbar.dart'; // ✅ Added for consistent notifications

// ============================================================================
// WIDGET CLASS
// ============================================================================

class EditCollectorProfilePage extends StatefulWidget {
  const EditCollectorProfilePage({super.key});

  @override
  State<EditCollectorProfilePage> createState() =>
      _EditCollectorProfilePageState();
}

class _EditCollectorProfilePageState extends State<EditCollectorProfilePage> {
  // ==========================================================================
  // 1. STATE VARIABLES
  // These hold the text controllers, image data, and loading states for the form
  // ==========================================================================

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _profilePicBase64; // Stores the profile picture as a Base64 string
  bool _isLoading = true; // Shows a loading spinner while fetching initial data
  bool _isSaving = false; // Shows a loading spinner on the save button

  // ==========================================================================
  // 2. LIFECYCLE METHODS
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    // Automatically load the collector's existing profile data when the page opens
    _loadProfile();
  }

  @override
  void dispose() {
    // Cleans up memory by disposing text controllers when the page is closed
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 3. DATA FETCHING & USER ACTIONS
  // ==========================================================================

  /// THESE CODES ARE FOR LOADING THE EXISTING PROFILE DATA.
  /// It fetches the current user's document from Firestore and pre-fills the
  /// text fields and profile picture so the collector can see and edit their current info.
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
          _isLoading = false; // Hide loading spinner once data is loaded
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  /// THESE CODES ARE FOR PICKING AND ENCODING A NEW PROFILE PICTURE.
  /// It opens the device's image gallery, compresses the image (quality: 50),
  /// reads it as bytes, and converts it to a Base64 string to be saved in Firestore.
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

  /// THESE CODES ARE FOR SAVING THE UPDATED PROFILE TO FIRESTORE.
  /// It validates that the name isn't empty, updates the user's document in the
  /// database with the new values, shows a success TopSnackBar, and returns to the previous screen.
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

      // Update only the specific fields in the user's Firestore document
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
          message: 'Profile updated successfully! ✅',
          backgroundColor: Colors.green,
        );
        // Return 'true' to tell the previous screen (HomePage) to refresh its data
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
  // This code renders the visual layout of the Collector Profile Edit screen
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while the initial profile data is being fetched
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
            // --- Profile Picture Section ---
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.green.shade100,
                    // Display the Base64 image if it exists, otherwise show a default truck icon
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
                  // Camera icon overlay to indicate the picture is clickable
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

            // --- Name Field ---
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

            // --- Phone Field ---
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

            // --- Vehicle Type Field ---
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

            // --- Service Area Field ---
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

            // --- Save Button ---
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
