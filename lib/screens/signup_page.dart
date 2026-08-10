import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting the date
import 'widgets/kala_kal_app_bar.dart';
import 'widgets/primary_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>(); // Added for validation
  
  // Controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController(); 
  final passwordController = TextEditingController();
  final addressController = TextEditingController(); 
  final birthdayController = TextEditingController(); 
  
  String _selectedRole = 'household';
  bool _isLoading = false;
  DateTime? _selectedDate; // To store the actual date object

  // Date Picker Function
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

  Future<void> signup() async {
    // Validate form before submitting
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a birthday.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      UserCredential user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      //  Save new user data to Firestore
      await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).set({
        "uid": user.user!.uid,
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(), 
        "address": addressController.text.trim(), 
        "birthday": Timestamp.fromDate(_selectedDate!), 
        "role": _selectedRole,
        "createdAt": FieldValue.serverTimestamp(),
        "rating": 0.0,
        "totalTransactions": 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed.";
      if (e.code == 'weak-password') message = 'Password is too weak.';
      else if (e.code == 'email-already-in-use') message = 'Email already exists.';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
      //  Wrapped in SingleChildScrollView to prevent keyboard overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.recycling, size: 80, color: Colors.green),
              const SizedBox(height: 10),
              
              // Name
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              // Email
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              // Phone Number
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Contact Number", prefixIcon: Icon(Icons.phone)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              // Password
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)),
                validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 10),
              
              //Birthday (Read-only, opens picker
              TextFormField(
                controller: birthdayController,
                readOnly: true,
                onTap: _selectBirthday,
                decoration: const InputDecoration(
                  labelText: "Birthday", 
                  prefixIcon: Icon(Icons.cake),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              // Address (Important Info)
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Complete Address", 
                  prefixIcon: Icon(Icons.home),
                  alignLabelWithHint: true,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              
              const SizedBox(height: 15),
              const Text("I am a:", style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              
              // Role Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'household',
                    groupValue: _selectedRole,
                    onChanged: (val) => setState(() => _selectedRole = val!),
                    activeColor: Colors.green,
                  ),
                  const Text('Household 🏠'),
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'collector',
                    groupValue: _selectedRole,
                    onChanged: (val) => setState(() => _selectedRole = val!),
                    activeColor: Colors.green,
                  ),
                  const Text('Junk Collector 🚛'),
                ],
              ),
              
              const SizedBox(height: 20),
              PrimaryButton(text: "SIGN UP", onPressed: signup, isLoading: _isLoading),
              const SizedBox(height: 20), // Extra padding at bottom
            ],
          ),
        ),
      ),
    );
  }
}