import 'dart:convert'; 
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/kala_kal_app_bar.dart';
import '../widgets/primary_button.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdayController = TextEditingController();

  // State variables
  bool _isLoading = false;
  DateTime? _selectedDate;
  File? _imageFile;
  String? _currentProfileBase64; // Changed from URL to Base64 string

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _currentProfileBase64 = data['profilePic']; // Load Base64 from Firestore
          
          if (data['birthday'] != null) {
            _selectedDate = (data['birthday'] as Timestamp).toDate();
            _birthdayController.text = DateFormat('MM/dd/yyyy').format(_selectedDate!);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); 
    
    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Convert image to Base64 string
  Future<String?> _convertImageToBase64() async {
    if (_imageFile == null) return _currentProfileBase64;
    
    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64String = base64Encode(bytes);
      return base64String;
    } catch (e) {
      debugPrint('❌ Error converting image: $e');
      return null;
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.green)),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Convert image to Base64 (if a new one was picked)
      final profileBase64 = await _convertImageToBase64();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'birthday': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : FieldValue.delete(),
        if (profileBase64 != null) 'profilePic': profileBase64, 
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully! ✅'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

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
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green.shade100,
                      // Decode Base64 to display image
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) 
                          : (_currentProfileBase64 != null 
                              ? MemoryImage(base64Decode(_currentProfileBase64!)) 
                              : null),
                      child: _imageFile == null && _currentProfileBase64 == null
                          ? Text(
                              (_nameController.text.isNotEmpty ? _nameController.text[0] : '?').toUpperCase(),
                              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green.shade800),
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
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Name
              const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.person_outline, color: Colors.green), filled: true, fillColor: Colors.white),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Email (Read Only)
              const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Row(children: [
                  Icon(Icons.email_outlined, color: Colors.grey.shade600), const SizedBox(width: 12),
                  Expanded(child: Text(FirebaseAuth.instance.currentUser?.email ?? 'N/A', style: TextStyle(color: Colors.grey.shade700))),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Email cannot be changed.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),

              // Phone Number
              const Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.phone, color: Colors.green), filled: true, fillColor: Colors.white),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone is required' : null,
              ),
              const SizedBox(height: 16),

              // Birthday
              const Text('Birthday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _selectBirthday,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.cake, color: Colors.green),
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.green),
                  filled: true, fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Birthday is required' : null,
              ),
              const SizedBox(height: 16),

              // Address
              const Text('Complete Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.home, color: Colors.green), alignLabelWithHint: true,
                  filled: true, fillColor: Colors.white,
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 30),

              // Save Button
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