import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'widgets/top_snackbar.dart'; 
import 'widgets/kala_kal_app_bar.dart';
import 'widgets/primary_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final birthdayController = TextEditingController();

  String _selectedRole = 'household';
  bool _isLoading = false;
  DateTime? _selectedDate;
  bool _obscurePassword = true;

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
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
        birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // ✅ SHOW MANDATORY TERMS AGREEMENT DIALOG
  Future<bool> _showTermsAgreementDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button, can't tap outside to close
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.assignment, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Accept Terms', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(
            children: const [
              Text(
                'By creating an account, you agree to the KalaKalApp Terms of Service and Privacy Policy.',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              SizedBox(height: 16),
              Text('1. Data Privacy: We collect your name, contact details, and location to facilitate scrap collection and bidding.', style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text('2. Location Tracking: Collectors must enable GPS to receive nearby notifications.', style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text('3. Transactions: Bids are binding once accepted. Both parties must confirm pickup.', style: TextStyle(fontSize: 13)),
              SizedBox(height: 8),
              Text('4. Community Standards: Fraudulent listings or harassment will result in account ban.', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // CANCEL
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // I AGREE
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('I AGREE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      TopSnackBar.show(
        context,
        message: 'Please fill all fields and select a birthday.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // ✅ SHOW TERMS AGREEMENT DIALOG BEFORE CREATING ACCOUNT
    final agreedToTerms = await _showTermsAgreementDialog();
    
    if (!agreedToTerms) {
      // User clicked CANCEL - signup is rejected
      if (mounted) {
        TopSnackBar.show(
          context,
          message: 'You must agree to the terms to create an account.',
          backgroundColor: Colors.orange,
        );
      }
      return;
    }

    // User clicked I AGREE - proceed with signup
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? homeLocation;

      if (_selectedRole == 'collector') {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() => _isLoading = false);
            TopSnackBar.show(
              context,
              message: 'Please enable Location Services to sign up as a Collector.',
              backgroundColor: Colors.red,
            );
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() => _isLoading = false);
            TopSnackBar.show(
              context,
              message: 'Location permission is required for Collectors.',
              backgroundColor: Colors.red,
            );
          }
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        homeLocation = {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      Map<String, dynamic> userData = {
        "uid": userCredential.user!.uid,
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
        "address": addressController.text.trim(),
        "birthday": Timestamp.fromDate(_selectedDate!),
        "role": _selectedRole,
        "createdAt": FieldValue.serverTimestamp(),
        "rating": 0.0,
        "totalTransactions": 0,
        "agreedToTerms": true,
        "agreedToTermsAt": FieldValue.serverTimestamp(),
      };

      if (homeLocation != null) {
        userData["homeLocation"] = homeLocation;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set(userData);

      if (mounted) {
        TopSnackBar.show(
          context,
          message: "Account created successfully! Please login.",
          backgroundColor: Colors.green,
        );
        
        // Go back to login page (no auto-login)
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed.";
      if (e.code == 'weak-password') message = 'Password is too weak.';
      else if (e.code == 'email-already-in-use') message = 'Email already exists.';

      if (mounted) {
        TopSnackBar.show(context, message: message, backgroundColor: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        TopSnackBar.show(context, message: e.toString(), backgroundColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    addressController.dispose();
    birthdayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      appBar: const KalaKalAppBar(title: "Create Account", showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.recycling, size: 80, color: Colors.green),
              const SizedBox(height: 10),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Contact Number", prefixIcon: Icon(Icons.phone)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
                  ),
                ),
                validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: birthdayController,
                readOnly: true,
                onTap: _selectBirthday,
                decoration: const InputDecoration(labelText: "Birthday", prefixIcon: Icon(Icons.cake), suffixIcon: Icon(Icons.calendar_today)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Complete Address", prefixIcon: Icon(Icons.home), alignLabelWithHint: true),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              const Text("I am a:", style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(value: 'household', groupValue: _selectedRole, onChanged: (val) => setState(() => _selectedRole = val!), activeColor: Colors.green),
                  const Text('Household '),
                  const SizedBox(width: 16),
                  Radio<String>(value: 'collector', groupValue: _selectedRole, onChanged: (val) => setState(() => _selectedRole = val!), activeColor: Colors.green),
                  const Text('Junk Collector 🚛'),
                ],
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: "SIGN UP",
                onPressed: signup,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}



