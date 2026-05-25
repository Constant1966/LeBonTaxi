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
      };

      await supabase.from('app_settings').upsert(updates);
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paramètres de Tarification",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Ces paramètres sont lus en temps réel par l'application client et chauffeur. Toute modification prend effet immédiatement.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Devise : HTG (Gourde haïtienne)", style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6366F1), fontWeight: FontWeight.w500, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 32),
              
              // Tarifs principaux
              Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Tarifs principaux", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : null)),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Tarif de base / Prise en charge (HTG)", controller: _baseFareController, icon: Icons.money, hint: "Ex: 50", isDark: isDark),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Tarif au kilomètre (HTG)", controller: _perKmController, icon: Icons.add_road, hint: "Ex: 150", isDark: isDark),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Tarif à la minute (HTG)", controller: _perMinuteController, icon: Icons.timer, hint: "Ex: 0", isDark: isDark),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Tarif minimum d'une course (HTG)", controller: _minimumFareController, icon: Icons.low_priority, hint: "Ex: 100", isDark: isDark),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              
              // Commission & Extras
              Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Commission & Suppléments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : null)),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Commission plateforme (%)", controller: _commissionController, icon: Icons.percent, hint: "Ex: 15", isDark: isDark),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Frais d'attente par minute (HTG)", controller: _waitingPerMinuteController, icon: Icons.hourglass_bottom, hint: "Ex: 10", isDark: isDark),
                    const SizedBox(height: 20),
                    _buildSettingField(label: "Supplément de nuit (HTG)", controller: _nightSurchargeController, icon: Icons.nightlight_round, hint: "Ex: 50", isDark: isDark),
                  ]),
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : _saveSettings,
                  icon: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                  label: Text(isSaving ? "Enregistrement..." : "Enregistrer les paramètres"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingField({required String label, required TextEditingController controller, required IconData icon, String? hint, required bool isDark}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Ce champ est obligatoire";
        if (double.tryParse(value) == null) return "Veuillez entrer un nombre valide";
        return null;
      },
    );
  }
}
