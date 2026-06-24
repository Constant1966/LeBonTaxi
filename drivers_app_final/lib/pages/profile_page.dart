import 'package:drivers_app/pages/settings_page.dart';
import 'package:drivers_app/pages/subscription_page.dart';
import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:drivers_app/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:drivers_app/authentication/login_screen.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/pages/profile_page_document_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin<ProfilePage> {
  double _averageRating = 0.0;
  int _totalRatings = 0;
  bool _isLoadingRatings = true;

  int _totalTrips = 0;
  double _totalEarnings = 0.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDriverStats();
  }

  Future<void> _loadDriverStats() async {
    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId == null) {
      setState(() => _isLoadingRatings = false);
      return;
    }

    try {
      final stats = await SupabaseService.getDriverStatistics();

      setState(() {
        _averageRating = (stats['rating'] as num?)?.toDouble() ?? 5.0;
        _totalRatings = stats['total_ratings'] as int? ?? 0;
        _totalTrips = stats['total_trips'] as int? ?? 0;
        _totalEarnings = (stats['total_earnings'] as num?)?.toDouble() ?? 0.0;
        _isLoadingRatings = false;
      });
    } catch (e) {
      print("❌ Erreur chargement stats: $e");
      setState(() => _isLoadingRatings = false);
    }
  }

  Future<void> _signOut() async {
    if (isDriverCurrentlyOnline) {
      try {
        await SupabaseService.toggleAvailability(false);
      } catch (e) {
        print("❌ Erreur mise hors ligne: $e");
      }
    }

    clearDriverData();
    await SupabaseService.signOut();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showSignOutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Déconnexion",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDriverCurrentlyOnline) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Vous êtes actuellement en ligne",
                          style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                "Êtes-vous sûr de vouloir vous déconnecter ?",
                style: TextStyle(
                    fontSize: 16, color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Annuler",
                  style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Déconnexion",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStatsCards(isDark),
                        const SizedBox(height: 20),
                        _buildInfoSection(theme, isDark),
                        const SizedBox(height: 20),
                        const ProfileDocumentSection(),
                        const SizedBox(height: 20),
                        _buildActionButtons(theme, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
                  child: driverPhoto.isEmpty
                      ? const Icon(Icons.person,
                          size: 50, color: AppColors.primary)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDriverCurrentlyOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    isDriverCurrentlyOnline ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            driverName.isNotEmpty ? driverName : "Chauffeur",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            driverEmail.isNotEmpty ? driverEmail : "",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          // Badge abonnement
          if (isDriverSubscribed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    currentSubscriptionPlanName ?? 'Premium',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          _isLoadingRatings
              ? const CircularProgressIndicator(color: Colors.white)
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "($_totalRatings notes)",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.drive_eta,
            value: _totalTrips.toString(),
            label: "Courses",
            color: Colors.blue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.attach_money,
            value: "${_totalEarnings.toStringAsFixed(0)} HTG",
            label: "Gains",
            color: Colors.green,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Informations",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              InkWell(
                onTap: () => _showEditProfileDialog(theme, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text("Modifier", style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
              Icons.phone, "Téléphone", driverPhone, theme),
          Divider(
              height: 24,
              color: isDark ? Colors.grey.shade700 : null),
          _buildInfoRow(Icons.email, "Email", driverEmail, theme),
          Divider(
              height: 24,
              color: isDark ? Colors.grey.shade700 : null),
          _buildInfoRow(
            Icons.directions_car,
            "Véhicule",
            "$carColor $carModel ($carNumber)",
            theme,
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(ThemeData theme, bool isDark) {
    final nameController = TextEditingController(text: driverName);
    final phoneController = TextEditingController(text: driverPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text("Modifier le profil", style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: "Nom complet",
                labelStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: "Téléphone",
                labelStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Annuler", style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPhone = phoneController.text.trim();
              if (newName.isEmpty || newPhone.isEmpty) return;

              Navigator.pop(ctx);
              try {
                final success = await SupabaseService.updateDriverProfile({
                  'name': newName,
                  'phone': newPhone,
                });
                if (success) {
                  // ✅ Mettre à jour les globales
                  driverName = newName;
                  driverPhone = newPhone;
                  // ✅ Mettre à jour le cache SQLite
                  final userId = SupabaseService.getCurrentUser()?.id;
                  if (userId != null) {
                    await LocalDatabaseService.saveDriverProfile({
                      'id': userId, 'name': newName, 'phone': newPhone,
                      'email': driverEmail, 'photo': driverPhoto,
                      'car_model': carModel, 'car_color': carColor,
                      'car_number': carNumber,
                    });
                  }
                  if (mounted) {
                    setState(() {});
                    SnackBarHelper.showSuccess(context, "Profil mis à jour avec succès");
                  }
                }
              } catch (e) {
                if (mounted) {
                  SnackBarHelper.showError(context, "Erreur: $e");
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color)),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : "Non renseigné",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.workspace_premium,
          label: "Mon Abonnement",
          color: isDriverSubscribed ? const Color(0xFFD97706) : AppColors.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubscriptionPage()),
            ).then((_) {
              // Rafraîchir les stats quand on revient
              _loadDriverStats();
              setState(() {});
            });
          },
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.settings,
          label: "Paramètres",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.logout,
          label: "Déconnexion",
          color: Colors.red,
          onTap: _showSignOutDialog,
          theme: theme,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: buttonColor.withOpacity(isDark ? 0.4 : 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: buttonColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: buttonColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: buttonColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}