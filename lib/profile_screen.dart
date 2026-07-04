import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'hostel_data.dart';
import 'timetable_entry_screen.dart';
import 'theme.dart';
import 'made_by_credit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;

  String? _firstName;
  String? _lastName;
  String? _gender;
  String? _hostel;
  String? _photoBase64;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  List<String> get _hostelOptions {
    if (_gender == 'Male') return boysHostels;
    if (_gender == 'Female') return girlsHostels;
    return [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc =
        await FirebaseFirestore.instance.collection('students').doc(_uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _firstName = data['firstName'];
      _lastName = data['lastName'];
      _gender = data['gender'];
      _hostel = data['hostelBlock'];
      _photoBase64 = data['photoBase64'];
      _loading = false;
    });
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
    final base64Str = base64Encode(bytes);

    setState(() {
      _photoBase64 = base64Str;
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('students').doc(_uid).set(
        {'photoBase64': base64Str},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHostel() async {
    if (_hostel == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('students').doc(_uid).set(
        {'hostelBlock': _hostel},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Hostel updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update hostel: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _saving ? null : _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.surfaceHigh,
                    backgroundImage: _photoBase64 != null
                        ? MemoryImage(base64Decode(_photoBase64!))
                        : null,
                    child: _photoBase64 == null
                        ? const Icon(Icons.person, size: 56, color: AppColors.textSecondary)
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
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${_firstName ?? ''} ${_lastName ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(_gender ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 32),
          const Text('Hostel Block',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _hostel,
            dropdownColor: AppColors.surfaceHigh,
            decoration: const InputDecoration(),
            items: _hostelOptions
                .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                .toList(),
            onChanged: (value) => setState(() => _hostel = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveHostel,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Hostel'),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),
          AccentBarCard(
            barColor: AppColors.accent,
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(child: Text('Edit your timetable')),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TimetableEntryScreen()),
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const MadeByCredit(),
        ],
      ),
    );
  }
}