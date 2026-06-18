import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:users_app/services/local_database_service.dart';
import 'package:users_app/appInfo/app_info.dart';
import 'package:users_app/authentication/login_screen_supabase.dart';
import 'package:users_app/pages/terms_conditions_page.dart';
import 'package:users_app/pages/privacy_policy_page.dart';
import 'package:users_app/pages/safety_guidelines_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _darkModeEnabled = prefs.getBool('darkMode') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('darkMode', _darkModeEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Paramètres enregistrés"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Paramètres"),
        backgroundColor: isDark ? const Color(0xFF1E1B4B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("Notifications", isDark),
          _buildSwitchTile(
            title: "Notifications push",
            subtitle: "Recevoir des alertes pour les nouvelles courses",
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("Apparence", isDark),
          _buildSwitchTile(
            title: "Mode sombre",
            subtitle: "Activer le thème sombre",
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() => _darkModeEnabled = value);
              Provider.of<AppInfo>(context, listen: false).updateThemeMode(value);
              _saveSettings();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("Compte", isDark),
          _buildActionTile(
            icon: Icons.explore_outlined,
            title: "Recommencer le guide d'accueil",
            color: isDark ? Colors.blue.shade300 : AppColors.primary,
            onTap: () async {
              await LocalDatabaseService.saveAppSetting('has_completed_guide', 'false');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🧭 Guide d'accueil réinitialisé. Retournez à l'accueil pour le recommencer."),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            isDark: isDark,
          ),
          _buildActionTile(
            icon: Icons.delete_outline,
            title: "Supprimer le compte",
            color: Colors.red,
            onTap: _showDeleteAccountDialog,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("À propos et Informations Légales", isDark),
          _buildActionTile(
            icon: Icons.description_outlined,
            title: "Conditions Générales d'Utilisation",
            color: isDark ? Colors.grey.shade400 : AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsPage())),
            isDark: isDark,
          ),
          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            title: "Politique de Confidentialité",
            color: isDark ? Colors.grey.shade400 : AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
            isDark: isDark,
          ),
          _buildActionTile(
            icon: Icons.shield_outlined,
            title: "Consignes de Sécurité",
            color: isDark ? Colors.grey.shade400 : AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyGuidelinesPage())),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildInfoTile("Version", "1.0.0", isDark),
          _buildInfoTile("Développé par", "Le Bon Taxi", isDark),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
  }) {
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF1E293B) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: Colors.grey.shade800) : BorderSide.none,
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : null)),
        subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey.shade400 : null)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF1E293B) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: Colors.grey.shade800) : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey.shade600 : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey.shade400 : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : null)),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer le compte"),
        content: const Text(
          "Cette action est irréversible. Toutes vos données seront supprimées.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("SUPPRIMER"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // ✅ Supprimer les données utilisateur de Supabase
      if (SupabaseService.isAuthenticated) {
        await SupabaseService.supabase
            .from('users')
            .delete()
            .eq('id', SupabaseService.userId!);
        print('✅ Données utilisateur supprimées de Supabase');
      }

      // ✅ Déconnexion
      await SupabaseService.signOut();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte supprimé avec succès"),
            backgroundColor: AppColors.success,
          ),
        );

        // ✅ Rediriger vers login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreenSupabase()),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ Erreur suppression compte: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}