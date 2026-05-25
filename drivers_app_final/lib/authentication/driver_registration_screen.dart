import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/authentication/login_screen.dart';
import 'package:drivers_app/theme/app_colors.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ninController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carColorController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();
  final TextEditingController carYearController = TextEditingController();

  // Vehicle type
  String _vehicleType = 'car';

  // Images
  XFile? _profilePhoto;
  XFile? _carFrontPhoto;
  XFile? _carBackPhoto;
  XFile? _carSidePhoto;
  XFile? _carInteriorPhoto; // ✅ Nouvelle photo
  XFile? _licensePhoto;

  bool _isLoading = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _loadExistingData();

    // Auto-format car number
    carNumberController.addListener(() {
      final text = carNumberController.text.toUpperCase();
      final cleanText = text.replaceAll('-', '');

      if (cleanText.length <= 7) {
        String formatted = '';
        if (cleanText.isNotEmpty) {
          formatted = cleanText.substring(
              0, cleanText.length > 2 ? 2 : cleanText.length);
        }
        if (cleanText.length > 2) {
          formatted += '-${cleanText.substring(2)}';
        }
        if (formatted != carNumberController.text) {
          carNumberController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      }
    });

    // Auto-format NIN (10 chiffres)
    ninController.addListener(() {
      final text = ninController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.length > 10) {
        ninController.value = TextEditingValue(
          text: text.substring(0, 10),
          selection: const TextSelection.collapsed(offset: 10),
        );
      }
    });
  }

  Future<void> _loadExistingData() async {
    final user = SupabaseService.getCurrentUser();
    if (user == null) return;

    final profile = await SupabaseService.getDriverProfile(user.id);
    if (profile != null) {
      setState(() {
        phoneController.text = profile['phone'] ?? '';
        ninController.text = profile['nin'] ?? '';
        _vehicleType = profile['vehicle_type'] ?? 'car';
        carModelController.text = profile['car_model'] ?? '';
        carColorController.text = profile['car_color'] ?? '';
        carNumberController.text = profile['car_number'] ?? '';
        carYearController.text = profile['car_year'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    phoneController.dispose();
    ninController.dispose();
    carModelController.dispose();
    carColorController.dispose();
    carNumberController.dispose();
    carYearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        switch (type) {
          case 'profile':
            _profilePhoto = image;
            break;
          case 'car_front':
            _carFrontPhoto = image;
            break;
          case 'car_back':
            _carBackPhoto = image;
            break;
          case 'car_side':
            _carSidePhoto = image;
            break;
          case 'car_interior':
            _carInteriorPhoto = image;
            break;
          case 'license':
            _licensePhoto = image;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        )
            : null,
        title: const Text(
          'Inscription Chauffeur',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              children: [
                _buildPage1(),
                _buildPage2(),
                _buildPage3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 2) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // PAGE 1 : Photo + Téléphone + NIN
  // ============================================================
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations Personnelles',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre photo, téléphone et NIN',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 32),

          // Photo de profil
          Center(
            child: GestureDetector(
              onTap: () => _pickImage('profile'),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: AppColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _profilePhoto != null
                    ? ClipOval(
                  child: Image.file(File(_profilePhoto!.path), fit: BoxFit.cover),
                )
                    : const Icon(Icons.add_a_photo, size: 45, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Tapez pour ajouter une photo',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 36),

          // Téléphone
          IntlPhoneField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
            ),
            initialCountryCode: 'HT',
            onChanged: (phone) {
              setState(() => _phoneNumber = phone.completeNumber);
            },
          ),
          const SizedBox(height: 20),

          // NIN
          TextField(
            controller: ninController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'NIN (Numéro Identification Nationale) *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              hintText: '0123456789',
              helperText: '10 chiffres obligatoires',
              helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.badge, color: AppColors.primary),
              counterText: '${ninController.text.length}/10',
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Info NIN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Le NIN (NINU) est votre numéro d\'identification nationale unique. Il est composé de 10 chiffres et est obligatoire.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bouton Suivant
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canContinuePage1() ? _goToPage2 : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _canContinuePage1() ? 4 : 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canContinuePage1() {
    return _phoneNumber != null &&
        _phoneNumber!.isNotEmpty &&
        ninController.text.length == 10;
  }

  void _goToPage2() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ============================================================
  // PAGE 2 : Type Véhicule + Infos + Photos
  // ============================================================
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations du Véhicule',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text('Détails de votre véhicule', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          // ✅ SÉLECTEUR DE TYPE DE VÉHICULE
          const Text(
            'Type de véhicule *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildVehicleTypeCard('🚗', 'Voiture', 'car')),
              const SizedBox(width: 12),
              Expanded(child: _buildVehicleTypeCard('🏍️', 'Moto', 'moto')),
              const SizedBox(width: 12),
              Expanded(child: _buildVehicleTypeCard('🚐', 'Van', 'van')),
            ],
          ),
          const SizedBox(height: 24),

          // Modèle
          TextField(
            controller: carModelController,
            decoration: InputDecoration(
              labelText: _vehicleType == 'moto'
                  ? 'Marque et Modèle (ex: Yamaha R15) *'
                  : 'Modèle (ex: Toyota Corolla) *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: Icon(
                _vehicleType == 'moto' ? Icons.two_wheeler : Icons.directions_car,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Couleur
          TextField(
            controller: carColorController,
            decoration: InputDecoration(
              labelText: 'Couleur (ex: Blanc) *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.palette, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Année
          TextField(
            controller: carYearController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Année (ex: 2020) *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              counterText: '',
              prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Plaque
          TextField(
            controller: carNumberController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: 'Plaque (format: AA-12345) *',
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
              counterText: '',
              prefixIcon: const Icon(Icons.confirmation_number, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 28),

          // Photos du véhicule
          Text(
            _vehicleType == 'moto' ? 'Photos de la moto *' : 'Photos du véhicule *',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),

          // 2 photos en haut
          Row(
            children: [
              Expanded(child: _buildPhotoCard('Avant', _carFrontPhoto, 'car_front')),
              const SizedBox(width: 12),
              Expanded(child: _buildPhotoCard('Arrière', _carBackPhoto, 'car_back')),
            ],
          ),
          const SizedBox(height: 12),

          // 2 photos en bas
          Row(
            children: [
              Expanded(child: _buildPhotoCard('Côté', _carSidePhoto, 'car_side')),
              const SizedBox(width: 12),
              // ✅ Photo intérieur (seulement pour voiture/van)
              if (_vehicleType != 'moto')
                Expanded(child: _buildPhotoCard('Intérieur', _carInteriorPhoto, 'car_interior')),
              if (_vehicleType == 'moto')
                Expanded(child: Container()), // Espace vide pour moto
            ],
          ),

          const SizedBox(height: 16),

          // Info photos
          if (_vehicleType != 'moto')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'La photo de l\'intérieur permet aux clients de voir la propreté et le confort de votre véhicule.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Bouton Suivant
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canContinuePage2() ? _goToPage3 : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _canContinuePage2() ? 4 : 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeCard(String emoji, String label, String type) {
    final isSelected = _vehicleType == type;

    return GestureDetector(
      onTap: () => setState(() => _vehicleType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canContinuePage2() {
    final basicFieldsValid = carModelController.text.isNotEmpty &&
        carColorController.text.isNotEmpty &&
        carYearController.text.isNotEmpty &&
        carNumberController.text.length >= 7 &&
        _carFrontPhoto != null &&
        _carBackPhoto != null &&
        _carSidePhoto != null;

    // Pour voiture/van, exiger photo intérieur
    if (_vehicleType == 'car' || _vehicleType == 'van') {
      return basicFieldsValid && _carInteriorPhoto != null;
    }

    // Pour moto, pas besoin de photo intérieur
    return basicFieldsValid;
  }

  void _goToPage3() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ============================================================
  // PAGE 3 : Permis
  // ============================================================
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permis de Conduire',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text('Photo de votre permis de conduire', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          _buildPhotoCard('Permis de Conduire *', _licensePhoto, 'license'),
          const SizedBox(height: 24),

          // Info vérification
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Votre compte sera vérifié automatiquement. Vous pourrez commencer à recevoir des courses immédiatement.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bouton Terminer
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canSubmit() ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _canSubmit() ? 4 : 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'Terminer l\'inscription',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String title, XFile? photo, String type) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: photo != null ? AppColors.success : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: photo != null
              ? [BoxShadow(color: AppColors.success.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: photo != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(photo.path), fit: BoxFit.cover),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    return !_isLoading && _licensePhoto != null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      print('📤 Upload des photos...');

      // Upload photos
      String? profilePhotoUrl;
      if (_profilePhoto != null) {
        profilePhotoUrl = await SupabaseService.uploadPhoto(_profilePhoto!.path, 'profiles');
      }

      final carFrontUrl = await SupabaseService.uploadPhoto(_carFrontPhoto!.path, 'cars');
      final carBackUrl = await SupabaseService.uploadPhoto(_carBackPhoto!.path, 'cars');
      final carSideUrl = await SupabaseService.uploadPhoto(_carSidePhoto!.path, 'cars');

      String? carInteriorUrl;
      if (_carInteriorPhoto != null) {
        carInteriorUrl = await SupabaseService.uploadPhoto(_carInteriorPhoto!.path, 'cars');
      }

      final licenseUrl = await SupabaseService.uploadPhoto(_licensePhoto!.path, 'licenses');

      if (carFrontUrl == null || carBackUrl == null || carSideUrl == null || licenseUrl == null) {
        throw Exception('Erreur upload photos');
      }

      print('✅ Photos uploadées');

      // Compléter le profil
      await SupabaseService.updateDriverProfile({
        'phone': _phoneNumber!,
        'nin': ninController.text.trim(),
        'vehicle_type': _vehicleType,
        'car_model': carModelController.text.trim(),
        'car_color': carColorController.text.trim(),
        'car_number': carNumberController.text.trim(),
        'car_year': carYearController.text.trim(),
        'car_front_photo': carFrontUrl,
        'car_back_photo': carBackUrl,
        'car_side_photo': carSideUrl,
        'car_interior_photo': carInteriorUrl,
        'license_photo': licenseUrl,
        'photo': profilePhotoUrl,
        'profile_completed': true,
      });

      print('✅ Profil complété');

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Inscription Réussie !', style: TextStyle(fontSize: 20))),
            ],
          ),
          content: const Text(
            'Votre compte a été créé avec succès ! Vous pouvez maintenant vous connecter et commencer à recevoir des courses.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goToLogin();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Erreur inscription: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Erreur: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    SupabaseService.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }
}