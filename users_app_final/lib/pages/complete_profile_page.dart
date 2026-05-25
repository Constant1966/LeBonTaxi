import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:users_app/services/photo_service.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/pages/home_page.dart';
import 'package:users_app/theme/app_colors.dart';

class CompleteProfilePage extends StatefulWidget {
  final String userId;
  final String email;
  final String? initialName;
  final bool skipNameNinPhone;

  const CompleteProfilePage({
    super.key,
    required this.userId,
    required this.email,
    this.initialName,
    this.skipNameNinPhone = false,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ninController = TextEditingController();

  String _phoneNumber = '';
  String _phoneCountryCode = '+509';
  File? _profilePhoto;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await PhotoService.showPhotoSourceDialog(context);
    if (photo != null) {
      setState(() => _profilePhoto = photo);
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profilePhoto == null && !widget.skipNameNinPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez prendre une photo de profil"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoUrl;

      if (_profilePhoto != null) {
        photoUrl = await PhotoService.uploadPhoto(_profilePhoto!, widget.userId);
        if (photoUrl == null) throw Exception("Échec upload photo");
      }

      final updateData = <String, dynamic>{
        'profile_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (photoUrl != null) {
        updateData['photo'] = photoUrl;
      }

      if (!widget.skipNameNinPhone) {
        updateData['name'] = _nameController.text.trim();
        updateData['nin'] = _ninController.text.trim();
        updateData['phone'] = _phoneCountryCode + _phoneNumber;
      }

      await SupabaseService.supabase
          .from('users')
          .update(updateData)
          .eq('id', widget.userId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.skipNameNinPhone
            ? "Ajoutez votre photo"
            : "Complétez votre profil"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quelques informations pour commencer",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // Photo de profil
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        image: _profilePhoto != null
                            ? DecorationImage(
                          image: FileImage(_profilePhoto!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _profilePhoto == null
                          ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _profilePhoto == null
                        ? "Touchez pour ajouter une photo"
                        : "Touchez pour changer la photo",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 32),

                // Champs conditionnels
                if (!widget.skipNameNinPhone) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Nom complet *",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Nom requis";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _ninController,
                    decoration: InputDecoration(
                      labelText: "NIN (10 chiffres) *",
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: "Numéro d'Identification National",
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "NIN requis";
                      }
                      if (value.trim().length != 10) {
                        return "NIN doit contenir 10 chiffres";
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                        return "NIN doit contenir que des chiffres";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  IntlPhoneField(
                    decoration: InputDecoration(
                      labelText: "Numéro de téléphone *",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    initialCountryCode: 'HT',
                    onChanged: (phone) {
                      _phoneNumber = phone.number;
                      _phoneCountryCode = '+${phone.countryCode}';
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.isEmpty) {
                        return "Téléphone requis";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // Bouton
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Continuer",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}