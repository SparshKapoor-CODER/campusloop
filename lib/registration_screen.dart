import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'hostel_data.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'made_by_credit.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _gender;
  String? _hostel;
  String? _photoBase64;
  bool _isSubmitting = false;

  List<String> get _hostelOptions {
    if (_gender == 'Male') return boysHostels;
    if (_gender == 'Female') return girlsHostels;
    return [];
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _hostel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender and hostel')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      await FirebaseFirestore.instance.collection('students').doc(user.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _gender,
        'hostelBlock': _hostel,
        'createdAt': FieldValue.serverTimestamp(),
        if (_photoBase64 != null) 'photoBase64': _photoBase64,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 24),
                Text('CAMPUSLOOP',
                    style: AppTheme.mono(
                        fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent)),
                const SizedBox(height: 4),
                Text("Let's get you set up.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.surfaceHigh,
                          backgroundImage: _photoBase64 != null
                              ? MemoryImage(base64Decode(_photoBase64!))
                              : null,
                          child: _photoBase64 == null
                              ? const Icon(Icons.person, size: 48, color: AppColors.textSecondary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  dropdownColor: AppColors.surfaceHigh,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _gender = value;
                      _hostel = null; // reset hostel when gender changes
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _hostel,
                  decoration: const InputDecoration(labelText: 'Hostel Block'),
                  dropdownColor: AppColors.surfaceHigh,
                  items: _hostelOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: _gender == null
                      ? null
                      : (value) => setState(() => _hostel = value),
                ),
                const SizedBox(height: 32),
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Continue'),
                        ),
                      ),
                const MadeByCredit(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}