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
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _phoneNumber = '';
  String _phoneCountryCode = '+509';
  File? _profilePhoto;
  bool _isLoading = false;
  bool _showReferralField = false;
  final _referralCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    _checkReferralStatus();
  }

  Future<void> _checkReferralStatus() async {
    try {
      final profile = await SupabaseService.getUserProfile();
      if (profile != null && profile['referred_by_id'] == null) {
        setState(() {
          _showReferralField = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ninController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _referralCodeController.dispose();
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

      if (_emergencyNameController.text.trim().isNotEmpty) {
        updateData['emergency_contact_name'] = _emergencyNameController.text.trim();
      }
      if (_emergencyPhoneController.text.trim().isNotEmpty) {
        updateData['emergency_contact_phone'] = _emergencyPhoneController.text.trim();
      }

      // Gestion du parrainage
      final existingProfile = await SupabaseService.getUserProfile();
      String? finalReferrerId = existingProfile?['referred_by_id']?.toString();

      if (finalReferrerId == null && _referralCodeController.text.trim().isNotEmpty) {
        final referrer = await SupabaseService.checkReferralCode(_referralCodeController.text.trim());
        if (referrer == null) {
          throw Exception("Le code de parrainage saisi est invalide.");
        }
        finalReferrerId = referrer['id'] as String;
      }

      if (finalReferrerId != null) {
        updateData['referred_by_id'] = finalReferrerId;
      }

      // Générer son propre code de parrainage s'il n'en a pas déjà un
      if (existingProfile?['referral_code'] == null) {
        final cleanName = _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase()
            : 'USER';
        final namePart = cleanName.length >= 4 ? cleanName.substring(0, 4) : (cleanName + 'LBT').substring(0, 4);
        final randomNum = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
        final myReferralCode = 'LBT-$namePart$randomNum';
        updateData['referral_code'] = myReferralCode;
      }

      await SupabaseService.updateUserProfile(updateData);

      // Déclencher la récompense de parrainage si applicable
      if (finalReferrerId != null) {
        try {
          await SupabaseService.triggerReferralReward(widget.userId, finalReferrerId);
        } catch (re) {
          print("⚠️ Erreur lors du déclenchement de la récompense: $re");
        }
      }

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
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
                        image: _profilePhoto != null
                            ? DecorationImage(
                          image: FileImage(_profilePhoto!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _profilePhoto == null
                          ? Icon(Icons.camera_alt, size: 40, color: AppColors.getTextSecondaryColor(context))
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
                    style: TextStyle(fontSize: 14, color: AppColors.getTextSecondaryColor(context)),
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
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    "Contact de confiance (Optionnel - Sécurité)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emergencyNameController,
                    decoration: InputDecoration(
                      labelText: "Nom du contact d'urgence",
                      prefixIcon: const Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emergencyPhoneController,
                    decoration: InputDecoration(
                      labelText: "Numéro de téléphone du contact",
                      prefixIcon: const Icon(Icons.phone_iphone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: "Exemple: +509 3123 4567",
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_showReferralField) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    "Code de parrainage (Optionnel)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referralCodeController,
                    decoration: InputDecoration(
                      labelText: "Code de parrainage / promo",
                      prefixIcon: const Icon(Icons.card_giftcard),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: "Si un ami vous a invité, entrez son code promo ici",
                    ),
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