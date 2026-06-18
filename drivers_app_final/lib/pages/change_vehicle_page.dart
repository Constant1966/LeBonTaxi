// lib/pages/change_vehicle_page.dart  (drivers_app_final)
//
// Permet au chauffeur de changer de véhicule et re-soumettre
// les documents associés. Met le compte en attente automatiquement.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/supabase_document_service.dart';
import 'package:drivers_app/services/image_quality_service.dart';
import 'package:drivers_app/widgets/document_upload_widget.dart';
import 'package:drivers_app/theme/app_colors.dart';

class ChangeVehiclePage extends StatefulWidget {
  const ChangeVehiclePage({super.key});

  @override
  State<ChangeVehiclePage> createState() => _ChangeVehiclePageState();
}

class _ChangeVehiclePageState extends State<ChangeVehiclePage> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ── Contrôleurs ──────────────────────────────────────────────────────────
  final _carModelCtrl  = TextEditingController();
  final _carColorCtrl  = TextEditingController();
  final _carNumberCtrl = TextEditingController();
  final _carYearCtrl   = TextEditingController();

  // ── Photos véhicule ───────────────────────────────────────────────────────
  File? _carFrontPhoto;

  // ── Documents véhicule obligatoires ───────────────────────────────────────
  final Map<String, File?> _docFiles = {
    'vehicle_registration': null,
    'vehicle_insurance': null,
    'technical_inspection': null, // optionnel
  };
  final Map<String, ImageQualityResult?> _docQualities = {};

  bool _submitting = false;
  int _currentStep = 0; // 0 = infos véhicule, 1 = documents, 2 = confirmation

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les valeurs actuelles
    _carModelCtrl.text  = carModel;
    _carColorCtrl.text  = carColor;
    _carNumberCtrl.text = carNumber;
    _carYearCtrl.text   = carYear;
  }

  @override
  void dispose() {
    _carModelCtrl.dispose();
    _carColorCtrl.dispose();
    _carNumberCtrl.dispose();
    _carYearCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _driverId => _client.auth.currentUser!.id;

  bool get _requiredDocsReady {
    return _docFiles['vehicle_registration'] != null &&
        _docQualities['vehicle_registration']?.isAcceptable == true &&
        _docFiles['vehicle_insurance'] != null &&
        _docQualities['vehicle_insurance']?.isAcceptable == true;
  }

  bool get _vehicleInfoComplete {
    return _carModelCtrl.text.trim().isNotEmpty &&
        _carColorCtrl.text.trim().isNotEmpty &&
        _carNumberCtrl.text.trim().isNotEmpty &&
        _carYearCtrl.text.trim().isNotEmpty &&
        _carFrontPhoto != null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _showConfirmationDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Confirmer le changement',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️ En changeant de véhicule, votre compte sera temporairement mis en attente le temps que l\'équipe Le Bon Taxi vérifie les documents de votre nouveau véhicule. Vous ne pourrez pas recevoir de courses pendant cette période.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nouveau véhicule :',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 6),
            _confirmRow('Modèle', _carModelCtrl.text, isDark, theme),
            _confirmRow('Couleur', _carColorCtrl.text, isDark, theme),
            _confirmRow('Plaque', _carNumberCtrl.text, isDark, theme),
            _confirmRow('Année', _carYearCtrl.text, isDark, theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirmer le changement',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _submitVehicleChange();
  }

  Widget _confirmRow(String label, String value, bool isDark, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  Future<void> _submitVehicleChange() async {
    setState(() => _submitting = true);

    try {
      // 1. Sauvegarder l'ancien véhicule
      final previousVehicle = {
        'car_model': carModel,
        'car_color': carColor,
        'car_number': carNumber,
        'car_year': carYear,
        'car_front_photo': carFrontPhoto,
        'changed_at': DateTime.now().toIso8601String(),
      };

      // 2. Upload photo avant véhicule
      _showProgress('Upload de la photo du véhicule…');
      final frontPhotoUrl = await SupabaseService.uploadPhoto(
          _carFrontPhoto!.path, 'cars');
      if (frontPhotoUrl == null) throw Exception('Erreur upload photo véhicule');

      // 3. Upload documents
      _showProgress('Upload des documents…');
      final uploadedDocs = <String, String>{};
      for (final entry in _docFiles.entries) {
        if (entry.value == null) continue;
        final url = await _client.uploadDocumentFile(
          driverId: _driverId,
          documentType: entry.key,
          file: entry.value!,
        );
        uploadedDocs[entry.key] = url;
      }

      // 4. Supprimer anciens documents véhicule de driver_documents
      //    (pour ne garder que les nouveaux)
      await _client.from('driver_documents').delete().eq('driver_id', _driverId).inFilter(
          'document_type',
          ['vehicle_registration', 'vehicle_insurance', 'technical_inspection']);

      // 5. Insérer les nouveaux documents
      for (final entry in uploadedDocs.entries) {
        await _client.submitDocument(
          driverId: _driverId,
          documentType: entry.key,
          fileUrl: entry.value,
        );
      }

      // 6. Mettre à jour le profil chauffeur
      _showProgress('Mise à jour du profil…');
      await _client.from('drivers').update({
        'car_model': _carModelCtrl.text.trim(),
        'car_color': _carColorCtrl.text.trim(),
        'car_number': _carNumberCtrl.text.trim(),
        'car_year': _carYearCtrl.text.trim(),
        'car_front_photo': frontPhotoUrl,
        'document_status': 'pending',
        'verified': false,
        'is_online': false,
        'is_available': false,
        'vehicle_change_pending': true,
        'previous_vehicle_info': previousVehicle,
      }).eq('id', _driverId);

      // 7. Mettre à jour les globales
      carModel    = _carModelCtrl.text.trim();
      carColor    = _carColorCtrl.text.trim();
      carNumber   = _carNumberCtrl.text.trim();
      carYear     = _carYearCtrl.text.trim();
      carFrontPhoto = frontPhotoUrl;
      isDriverCurrentlyOnline = false;
      driverDocumentStatus = 'pending';

      // 8. ✅ Email de confirmation changement de véhicule
      try {
        await _client.functions.invoke(
          'send-driver-email',
          body: {
            'to': driverEmail,
            'subject': '🔄 Changement de véhicule reçu — Le Bon Taxi',
            'html': _buildVehicleChangeEmailHtml(),
          },
        );
      } catch (emailError) {
        print('[Email] Erreur envoi changement véhicule: $emailError');
      }

      if (mounted) Navigator.pop(context); // fermer le dialog de progress

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text('Changement soumis !',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ]),
            content: const Text(
              'Vos documents ont été soumis avec succès. Notre équipe va les vérifier dans les 24-48h. Vous recevrez une notification dès que votre dossier sera traité.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // retour aux paramètres
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // fermer le dialog de progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Email HTML ────────────────────────────────────────────────────────────

  String _buildVehicleChangeEmailHtml() {
    final year = DateTime.now().year;
    final newModel  = _carModelCtrl.text.trim();
    final newNumber = _carNumberCtrl.text.trim();
    return '''<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <tr><td style="background:#6366F1;padding:32px 40px;text-align:center;">
          <div style="font-size:48px;margin-bottom:12px;">🔄</div>
          <h1 style="color:#fff;margin:0;font-size:22px;font-weight:700;">Changement de véhicule reçu</h1>
        </td></tr>
        <tr><td style="background:#1E1B4B;padding:10px 40px;text-align:center;">
          <span style="color:#fff;font-size:16px;font-weight:700;">🚕 Le Bon Taxi</span>
        </td></tr>
        <tr><td style="padding:32px 40px;">
          <p style="color:#374151;font-size:16px;margin:0 0 16px;">Bonjour <strong>$driverName</strong>,</p>
          <p style="color:#4B5563;font-size:15px;line-height:1.7;margin:0 0 16px;">
            Nous avons bien reçu les documents de votre nouveau véhicule :
          </p>
          <div style="background:#EEF2FF;border-left:4px solid #6366F1;padding:14px 18px;border-radius:0 10px 10px 0;margin:0 0 20px;">
            <strong style="color:#4338CA;">$newModel</strong> — Plaque : <strong style="color:#4338CA;">$newNumber</strong>
          </div>
          <p style="color:#4B5563;font-size:15px;line-height:1.7;margin:0 0 16px;">
            Votre dossier est <strong>en cours de vérification</strong> par notre équipe (24-48h).
          </p>
          <div style="background:#FEF3C7;border-left:4px solid #F59E0B;padding:12px 16px;border-radius:0 8px 8px 0;margin:0 0 20px;">
            <span style="color:#92400E;font-size:13px;">⚠️ Votre compte est temporairement suspendu pendant la vérification.</span>
          </div>
          <p style="color:#6B7280;font-size:13px;margin:0;">
            Questions ? <a href="mailto:constantlorvenson@gmail.com" style="color:#6366F1;">constantlorvenson@gmail.com</a> ou 
            <a href="https://wa.me/50946894905" style="color:#25D366;">WhatsApp +509 46 89 49 05</a>
          </p>
        </td></tr>
        <tr><td style="padding:20px 40px;text-align:center;border-top:1px solid #E5E7EB;">
          <p style="color:#9CA3AF;font-size:12px;margin:0;">© $year Le Bon Taxi — Haïti</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>''';
  }

  void _showProgress(String message) {
    // Fermer l'ancien dialog si ouvert
    try {
      Navigator.pop(context);
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Changer de véhicule',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1B4B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stepper indicator
          _buildStepIndicator(isDark),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: _currentStep == 0
                    ? _buildVehicleInfoStep(theme, isDark)
                    : _buildDocumentsStep(theme, isDark),
              ),
            ),
          ),

          // Bottom bar
          _buildBottomBar(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : AppColors.primary,
      ),
      child: Row(
        children: [
          _stepChip('1', 'Infos véhicule', _currentStep >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.white.withOpacity(_currentStep >= 1 ? 0.8 : 0.3),
            ),
          ),
          _stepChip('2', 'Documents', _currentStep >= 1),
        ],
      ),
    );
  }

  Widget _stepChip(String number, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primary : Colors.white,
                    fontSize: 14)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(active ? 1.0 : 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Step 1 : Infos véhicule ───────────────────────────────────────────────

  Widget _buildVehicleInfoStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre compte sera mis en attente pendant la vérification des documents de votre nouveau véhicule.',
                  style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 13,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),

        Text('Informations du nouveau véhicule',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _carModelCtrl,
          label: 'Modèle du véhicule',
          hint: 'Ex: Toyota Corolla',
          icon: Icons.directions_car,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _carColorCtrl,
          label: 'Couleur',
          hint: 'Ex: Blanc',
          icon: Icons.palette,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _carNumberCtrl,
          label: 'Plaque d\'immatriculation',
          hint: 'Ex: HA-1234',
          icon: Icons.pin,
          theme: theme,
          isDark: isDark,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _carYearCtrl,
          label: 'Année du véhicule',
          hint: 'Ex: 2020',
          icon: Icons.calendar_today,
          theme: theme,
          isDark: isDark,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),

        // Photo avant véhicule
        Text('Photo avant du véhicule *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 10),
        _buildPhotoPickerCard(theme, isDark),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: (v) =>
      v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
    );
  }

  Widget _buildPhotoPickerCard(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: _pickCarFrontPhoto,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: _carFrontPhoto != null
              ? null
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _carFrontPhoto != null
                ? Colors.green
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            width: 2,
          ),
        ),
        child: _carFrontPhoto != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_carFrontPhoto!, fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Photo OK',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _pickCarFrontPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 40,
                color: isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade500),
            const SizedBox(height: 8),
            Text('Appuyer pour prendre une photo',
                style: TextStyle(
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCarFrontPhoto() async {
    final source = await _showSourceDialog();
    if (source == null) return;
    final xFile = await _picker.pickImage(
        source: source, imageQuality: 90, maxWidth: 2048);
    if (xFile != null) setState(() => _carFrontPhoto = File(xFile.path));
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choisir depuis la galerie'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
  }

  // ── Step 2 : Documents ────────────────────────────────────────────────────

  Widget _buildDocumentsStep(ThemeData theme, bool isDark) {
    final requiredDocs = [
      {'type': 'vehicle_registration', 'label': 'Carte grise du véhicule', 'required': true},
      {'type': 'vehicle_insurance', 'label': 'Assurance véhicule', 'required': true},
      {'type': 'technical_inspection', 'label': 'Visite technique', 'required': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress header
        _buildDocProgress(),
        const SizedBox(height: 20),

        Text('Documents du nouveau véhicule',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 4),
        Text('Seuls les documents véhicule sont requis. Votre permis, CIN et casier restent valides.',
            style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 16),

        ...requiredDocs.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DocumentUploadWidget(
            documentType: doc['type'] as String,
            label: doc['label'] as String,
            isRequired: doc['required'] as bool,
            onDocumentSelected: (file, quality) {
              setState(() {
                _docFiles[doc['type'] as String] = file;
                _docQualities[doc['type'] as String] = quality;
              });
            },
          ),
        )),
      ],
    );
  }

  Widget _buildDocProgress() {
    final done = _docFiles.entries
        .where((e) =>
    e.value != null && _docQualities[e.key]?.isAcceptable == true)
        .length;
    const total = 2; // obligatoires seulement

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done == total ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done == total
              ? Colors.green.withOpacity(0.3)
              : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              done == total ? Icons.check_circle : Icons.upload_file,
              color: done == total ? Colors.green : Colors.blue,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$done/$total documents obligatoires prêts',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: done == total ? Colors.green : Colors.blue,
                  fontSize: 13),
            ),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? done / total : 0,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: done == total ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retour'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _submitting ? null : _onNextPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(
                _currentStep == 0 ? 'Continuer' : 'Soumettre le changement',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNextPressed() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_carFrontPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Veuillez ajouter une photo du véhicule'),
            backgroundColor: Colors.orange));
        return;
      }
      setState(() => _currentStep = 1);
    } else {
      if (!_requiredDocsReady) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
            Text('Veuillez soumettre la carte grise et l\'assurance'),
            backgroundColor: Colors.orange));
        return;
      }
      _showConfirmationDialog();
    }
  }
}