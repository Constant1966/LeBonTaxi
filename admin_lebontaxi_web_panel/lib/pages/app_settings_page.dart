import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_log_service.dart';

class AppSettingsPage extends StatefulWidget {
  static const String id = "\\webPageAppSettings";

  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  bool isSaving = false;

  // Controllers alignés sur les colonnes Supabase réelles
  final TextEditingController _baseFareController = TextEditingController();
  final TextEditingController _perKmController = TextEditingController();
  final TextEditingController _perMinuteController = TextEditingController();
  final TextEditingController _minimumFareController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _waitingPerMinuteController = TextEditingController();
  final TextEditingController _nightSurchargeController = TextEditingController();
  
  // Contacts d'assistance
  final TextEditingController _supportEmailController = TextEditingController();
  final TextEditingController _supportPhoneController = TextEditingController();
  final TextEditingController _supportWhatsappController = TextEditingController();

  // App Versions & URLs
  final TextEditingController _userAppVersionController = TextEditingController();
  final TextEditingController _userAppUrlController = TextEditingController();
  final TextEditingController _driverAppVersionController = TextEditingController();
  final TextEditingController _driverAppUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await supabase.from('app_settings').select().eq('id', 1).maybeSingle();
      if (response != null) {
        _baseFareController.text = response['base_fare']?.toString() ?? "0";
        _perKmController.text = response['per_km_rate']?.toString() ?? "150";
        _perMinuteController.text = response['per_minute_fare']?.toString() ?? "0";
        _minimumFareController.text = response['minimum_fare']?.toString() ?? "100";
        _commissionController.text = response['commission_percentage']?.toString() ?? "0";
        _waitingPerMinuteController.text = response['waiting_per_minute']?.toString() ?? "0";
        _nightSurchargeController.text = response['night_surcharge']?.toString() ?? "0";
        
        // Contacts d'assistance avec fallback
        _supportEmailController.text = response['support_email']?.toString() ?? "constantlorvenson@gmail.com";
        _supportPhoneController.text = response['support_phone']?.toString() ?? "+50946894905";
        _supportWhatsappController.text = response['support_whatsapp']?.toString() ?? "https://wa.me/50946894905";
        
        // Versions
        _userAppVersionController.text = response['user_app_version']?.toString() ?? "1.0.0";
        _userAppUrlController.text = response['user_app_url']?.toString() ?? "";
        _driverAppVersionController.text = response['driver_app_version']?.toString() ?? "1.0.0";
        _driverAppUrlController.text = response['driver_app_url']?.toString() ?? "";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de chargement: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ Confirmation avant sauvegarde
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Confirmer les changements", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  "Ces changements seront appliqués immédiatement à toutes les applications (chauffeurs et clients).",
                  style: TextStyle(fontSize: 12, color: Colors.red),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Text("Nouveaux tarifs:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            _confirmRow("Prise en charge", "${_baseFareController.text} HTG", isDark),
            _confirmRow("Par km", "${_perKmController.text} HTG", isDark),
            _confirmRow("Par minute", "${_perMinuteController.text} HTG", isDark),
            _confirmRow("Minimum", "${_minimumFareController.text} HTG", isDark),
            _confirmRow("Commission", "${_commissionController.text}%", isDark),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              child: const Text("Confirmer et sauvegarder"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => isSaving = true);

    try {
      final Map<String, dynamic> updates = {
        'id': 1,
        'base_fare': double.tryParse(_baseFareController.text) ?? 0.0,
        'per_km_rate': double.tryParse(_perKmController.text) ?? 150.0,
        'per_minute_fare': double.tryParse(_perMinuteController.text) ?? 0.0,
        'minimum_fare': double.tryParse(_minimumFareController.text) ?? 100.0,
        'commission_percentage': double.tryParse(_commissionController.text) ?? 0.0,
        'waiting_per_minute': double.tryParse(_waitingPerMinuteController.text) ?? 0.0,
        'night_surcharge': double.tryParse(_nightSurchargeController.text) ?? 0.0,
        'support_email': _supportEmailController.text.trim(),
        'support_phone': _supportPhoneController.text.trim(),
        'support_whatsapp': _supportWhatsappController.text.trim(),
        'user_app_version': _userAppVersionController.text.trim(),
        'user_app_url': _userAppUrlController.text.trim(),
        'driver_app_version': _driverAppVersionController.text.trim(),
        'driver_app_url': _driverAppUrlController.text.trim(),
      };

      try {
        await supabase.from('app_settings').update(updates).eq('id', 1);
      } catch (dbErr) {
        // Fallback sans les colonnes de support si elles n'existent pas dans la table
        final fallbackUpdates = Map<String, dynamic>.from(updates)
          ..remove('support_email')
          ..remove('support_phone')
          ..remove('support_whatsapp');
        await supabase.from('app_settings').update(fallbackUpdates).eq('id', 1);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Tarifs enregistrés, mais les contacts de support nécessitent d'exécuter la migration SQL dans Supabase."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      await AdminLogService.log(action: 'Modification tarification', targetType: 'settings', targetId: '1', details: updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Paramètres enregistrés — les apps se mettront à jour automatiquement"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _confirmRow(String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
    ]),
  );

  @override
  void dispose() {
    _baseFareController.dispose();
    _perKmController.dispose();
    _perMinuteController.dispose();
    _minimumFareController.dispose();
    _commissionController.dispose();
    _waitingPerMinuteController.dispose();
    _nightSurchargeController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _supportWhatsappController.dispose();
    _userAppVersionController.dispose();
    _userAppUrlController.dispose();
    _driverAppVersionController.dispose();
    _driverAppUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Paramètres de l'Application",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Modifiez les tarifs et les contacts d'assistance. Les changements sont appliqués en temps réel.",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveSettings,
                      icon: isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 20),
                      label: Text(isSaving ? "Enregistrement..." : "Sauvegarder"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shadowColor: AppColors.primary.withOpacity(0.3),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Currency Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text("Devise actuelle : ", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  const Text("HTG (Gourde haïtienne)", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 40),
              
              // Responsive Layout for Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  // Determine card width based on screen size
                  final double cardWidth = constraints.maxWidth > 1000 
                      ? (constraints.maxWidth - 32) / 2 // 2 columns
                      : constraints.maxWidth; // 1 column

                  return Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    children: [
                      // Section 1: Tarifs Principaux
                      SizedBox(
                        width: cardWidth,
                        child: _buildSectionCard(
                          title: "Tarifs Principaux",
                          icon: Icons.attach_money_rounded,
                          isDark: isDark,
                          children: [
                            _buildSettingField(label: "Prise en charge (Base)", controller: _baseFareController, icon: Icons.flag_rounded, hint: "Ex: 50"),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Prix au kilomètre", controller: _perKmController, icon: Icons.add_road_rounded, hint: "Ex: 150"),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Prix à la minute", controller: _perMinuteController, icon: Icons.timer_outlined, hint: "Ex: 0"),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Tarif minimum garanti", controller: _minimumFareController, icon: Icons.verified_user_outlined, hint: "Ex: 100"),
                          ],
                        ),
                      ),
                      
                      // Section 2: Commission & Extras
                      SizedBox(
                        width: cardWidth,
                        child: _buildSectionCard(
                          title: "Commission & Extras",
                          icon: Icons.percent_rounded,
                          isDark: isDark,
                          children: [
                            _buildSettingField(label: "Commission Plateforme (%)", controller: _commissionController, icon: Icons.pie_chart_outline_rounded, hint: "Ex: 15"),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Frais d'attente / min", controller: _waitingPerMinuteController, icon: Icons.hourglass_bottom_rounded, hint: "Ex: 10"),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Majoration de nuit", controller: _nightSurchargeController, icon: Icons.nights_stay_outlined, hint: "Ex: 50"),
                          ],
                        ),
                      ),

                      // Section 3: Assistance
                      SizedBox(
                        width: cardWidth,
                        child: _buildSectionCard(
                          title: "Contact & Assistance",
                          icon: Icons.support_agent_rounded,
                          isDark: isDark,
                          children: [
                            _buildSettingField(label: "Email de support", controller: _supportEmailController, icon: Icons.alternate_email_rounded, hint: "support@lebontaxi.com", isNumeric: false),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Téléphone d'urgence", controller: _supportPhoneController, icon: Icons.phone_rounded, hint: "+509 XXXX XXXX", isNumeric: false),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Lien WhatsApp direct", controller: _supportWhatsappController, icon: Icons.chat_bubble_outline_rounded, hint: "https://wa.me/509...", isNumeric: false),
                          ],
                        ),
                      ),

                      // Section 4: Mises à jour Applications
                      SizedBox(
                        width: cardWidth,
                        child: _buildSectionCard(
                          title: "Mises à jour des Apps (APK)",
                          icon: Icons.system_update_rounded,
                          isDark: isDark,
                          children: [
                            _buildSettingField(label: "Version App Utilisateur", controller: _userAppVersionController, icon: Icons.person_rounded, hint: "Ex: 1.0.0", isNumeric: false),
                            const SizedBox(height: 10),
                            _buildSettingField(label: "Lien APK Utilisateur", controller: _userAppUrlController, icon: Icons.link_rounded, hint: "https://...", isNumeric: false),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),
                            _buildSettingField(label: "Version App Chauffeur", controller: _driverAppVersionController, icon: Icons.drive_eta_rounded, hint: "Ex: 1.0.0", isNumeric: false),
                            const SizedBox(height: 10),
                            _buildSettingField(label: "Lien APK Chauffeur", controller: _driverAppUrlController, icon: Icons.link_rounded, hint: "https://...", isNumeric: false),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    String? hint, 
    bool isNumeric = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        // All styling borders are now inherited globally from theme_provider.dart
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return "Ce champ est obligatoire";
        if (isNumeric && double.tryParse(value) == null) return "Valeur invalide";
        return null;
      },
    );
  }
}
