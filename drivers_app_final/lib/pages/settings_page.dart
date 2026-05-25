import 'package:drivers_app/authentication/login_screen.dart';
import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/biometric_service.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:drivers_app/theme/theme_provider.dart';

import '../widgets/loading_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  String _appVersion = "1.0.0";
  bool _notificationsEnabled = true;
  bool _locationTrackingEnabled = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricLabel = '';

  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnim;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadBiometricState();

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    );
    _headerAnimController.forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() => _appVersion = packageInfo.version);
    } catch (e) {
      _appVersion = "1.0.0";
    }
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    final label = await BiometricService.getBiometricTypeLabel();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _biometricLabel = label;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authenticated = await BiometricService.authenticate(
        reason: 'Confirmez votre identité pour activer la biométrie',
      );
      if (!authenticated) {
        if (mounted) {
          _showSnackBar('Authentification échouée', isError: true);
        }
        return;
      }
    }

    await BiometricService.setBiometricEnabled(value);
    setState(() => _biometricEnabled = value);

    if (mounted) {
      _showSnackBar(value ? '🔒 Biométrie activée' : '🔓 Biométrie désactivée');
    }
  }

  Future<void> _updatePhoto(String type) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(messageText: "Mise à jour..."),
    );

    try {
      final folder = type == 'profile' ? 'profiles' : 'cars';
      final photoUrl = await SupabaseService.uploadPhoto(image.path, folder);

      if (photoUrl == null) throw Exception("Erreur lors de l'upload");

      Map<String, dynamic> updateData = {};
      if (type == 'profile') {
        updateData['photo'] = photoUrl;
      } else {
        updateData['car_front_photo'] = photoUrl;
      }

      final success = await SupabaseService.updateDriverProfile(updateData);
      if (mounted) Navigator.pop(context);

      if (success) {
        setState(() {
          if (type == 'profile') {
            driverPhoto = photoUrl;
          } else {
            carFrontPhoto = photoUrl;
          }
        });
        if (mounted) _showSnackBar("Photo mise à jour ✓");
      } else {
        throw Exception("Erreur lors de la mise à jour");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showSnackBar("Erreur : ${e.toString()}", isError: true);
    }
  }

  Future<void> _signOut() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text("Déconnexion",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir vous déconnecter ?",
          style: TextStyle(
              fontSize: 15, height: 1.5, color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isDriverCurrentlyOnline) {
                await SupabaseService.toggleAvailability(false);
              }
              clearDriverData();
              await SupabaseService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Déconnexion",
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text("Supprimer le compte",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("⚠️ Action irréversible",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Text(
              "Toutes vos données seront définitivement supprimées :\n\n• Profil chauffeur\n• Historique des courses\n• Gains et statistiques\n\nCette action ne peut pas être annulée.",
              style: TextStyle(height: 1.5, color: theme.textTheme.bodyMedium?.color),
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
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const LoadingDialog(messageText: "Suppression..."),
              );
              try {
                final userId = SupabaseService.getCurrentUser()?.id;
                if (userId != null) {
                  // ✅ Supprimer les données du chauffeur
                  final supabase = Supabase.instance.client;
                  await supabase.from('driver_earnings').delete().eq('driver_id', userId);
                  await supabase.from('trip_requests').update({'driver_id': null}).eq('driver_id', userId);
                  await supabase.from('drivers').delete().eq('id', userId);
                  print('✅ Données chauffeur supprimées de Supabase');
                }
                // ✅ Vider le cache SQLite
                await LocalDatabaseService.clearAll();
                print('✅ Cache SQLite vidé');
                
                // ✅ Nettoyer les variables globales
                clearDriverData();
                await SupabaseService.signOut();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                  _showSnackBar("Compte supprimé");
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Erreur: $e", isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Supprimer",
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackBar("Impossible d'ouvrir le lien", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(isDark),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Stats ──
                    _buildQuickStats(theme, isDark),
                    const SizedBox(height: 32),

                    // ── Photos ──
                    _buildSectionHeader("Photos", Icons.photo_library_rounded, theme),
                    const SizedBox(height: 14),
                    _buildPhotoSection(theme, isDark),
                    const SizedBox(height: 28),

                    // ── Préférences ──
                    _buildSectionHeader("Préférences", Icons.tune_rounded, theme),
                    const SizedBox(height: 14),
                    _buildGlassCard(
                      theme: theme,
                      isDark: isDark,
                      children: [
                        _buildModernSwitch(
                          icon: Icons.notifications_active_rounded,
                          title: "Notifications",
                          subtitle: "Alertes de nouvelles courses",
                          value: _notificationsEnabled,
                          onChanged: (val) =>
                              setState(() => _notificationsEnabled = val),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildModernSwitch(
                          icon: Icons.my_location_rounded,
                          title: "Suivi de position",
                          subtitle: "Partager ma localisation",
                          value: _locationTrackingEnabled,
                          onChanged: (val) =>
                              setState(() => _locationTrackingEnabled = val),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return _buildModernSwitch(
                              icon: Icons.dark_mode_rounded,
                              title: "Mode Sombre",
                              subtitle: "Thème clair ou sombre",
                              value: themeProvider.isDarkMode,
                              onChanged: (val) => themeProvider.toggleTheme(val),
                              theme: theme,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Sécurité ──
                    if (_biometricAvailable) ...[
                      _buildSectionHeader("Sécurité", Icons.shield_rounded, theme),
                      const SizedBox(height: 14),
                      _buildGlassCard(
                        theme: theme,
                        isDark: isDark,
                        children: [
                          _buildModernSwitch(
                            icon: Icons.fingerprint,
                            title: _biometricLabel,
                            subtitle: _biometricEnabled
                                ? 'Activé — requis au démarrage'
                                : 'Désactivé — activer pour sécuriser l\'app',
                            value: _biometricEnabled,
                            onChanged: _toggleBiometric,
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Support ──
                    _buildSectionHeader("Aide & Support", Icons.headset_mic_rounded, theme),
                    const SizedBox(height: 14),
                    _buildGlassCard(
                      theme: theme,
                      isDark: isDark,
                      children: [
                        _buildActionTile(
                          icon: Icons.help_center_rounded,
                          title: "Centre d'aide",
                          subtitle: "FAQ et guides",
                          onTap: () => _openUrl("https://lebontaxi.ht/help"),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildActionTile(
                          icon: Icons.email_rounded,
                          title: "Email",
                          subtitle: "support@lebontaxi.ht",
                          onTap: () => _openUrl("mailto:support@lebontaxi.ht"),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildActionTile(
                          icon: Icons.phone_rounded,
                          title: "Téléphone",
                          subtitle: "+509 1234 5678",
                          onTap: () => _openUrl("tel:+50912345678"),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildActionTile(
                          icon: Icons.chat_bubble_rounded,
                          title: "WhatsApp",
                          subtitle: "Chat en direct",
                          onTap: () => _openUrl("https://wa.me/50912345678"),
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Légal + À propos ──
                    _buildSectionHeader("Informations", Icons.info_rounded, theme),
                    const SizedBox(height: 14),
                    _buildGlassCard(
                      theme: theme,
                      isDark: isDark,
                      children: [
                        _buildActionTile(
                          icon: Icons.article_rounded,
                          title: "Conditions d'utilisation",
                          subtitle: "Voir les CGU",
                          onTap: () => _openUrl("https://lebontaxi.ht/terms"),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildActionTile(
                          icon: Icons.privacy_tip_rounded,
                          title: "Confidentialité",
                          subtitle: "Politique de données",
                          onTap: () => _openUrl("https://lebontaxi.ht/privacy"),
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildInfoRow(
                          icon: Icons.smartphone_rounded,
                          title: "Version",
                          value: _appVersion,
                          theme: theme,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Zone Danger ──
                    _buildDangerZone(theme, isDark),
                    const SizedBox(height: 40),

                    // ── Footer ──
                    _buildFooter(theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  Widget _buildModernAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFF6366F1),
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          driverName.isNotEmpty ? driverName : "Chauffeur",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF3730A3)]
                  : [const Color(0xFF4F46E5), const Color(0xFF6366F1), const Color(0xFF818CF8)],
            ),
          ),
          child: Stack(
            children: [
              // Motifs décoratifs
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Avatar
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () => _updatePhoto('profile'),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white,
                              backgroundImage: driverPhoto.isNotEmpty
                                  ? NetworkImage(driverPhoto)
                                  : null,
                              child: driverPhoto.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 48, color: Color(0xFF6366F1))
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (driverEmail.isNotEmpty)
                      Text(
                        driverEmail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _buildQuickStats(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatChip("🚗", carModel.isNotEmpty ? carModel : "—", theme),
          Container(
              width: 1,
              height: 35,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          _buildStatChip("🎨", carColor.isNotEmpty ? carColor : "—", theme),
          Container(
              width: 1,
              height: 35,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          _buildStatChip("🔢", carNumber.isNotEmpty ? carNumber : "—", theme),
        ],
      ),
    );
  }

  Widget _buildStatChip(String emoji, String value, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PHOTO SECTION
  // ============================================================

  Widget _buildPhotoSection(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildPhotoCard(
            title: "Photo Profil",
            icon: Icons.face_rounded,
            imageUrl: driverPhoto,
            onTap: () => _updatePhoto('profile'),
            theme: theme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildPhotoCard(
            title: "Véhicule",
            icon: Icons.directions_car_rounded,
            imageUrl: carFrontPhoto,
            onTap: () => _updatePhoto('car'),
            theme: theme,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard({
    required String title,
    required IconData icon,
    required String imageUrl,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(imageUrl,
                          fit: BoxFit.cover, width: 64, height: 64),
                    )
                  : Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text("Modifier",
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPOSANTS RÉUTILISABLES
  // ============================================================

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyLarge?.color,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required List<Widget> children,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
        height: 1,
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        indent: 76,
        endIndent: 20);
  }

  Widget _buildModernSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "v$value",
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DANGER ZONE
  // ============================================================

  Widget _buildDangerZone(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.red.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: isDark ? 0.1 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header avec dégradé rouge subtil
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.06),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded,
                    size: 18, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Text(
                  "Zone sensible",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          _buildDangerTile(
            icon: Icons.logout_rounded,
            title: "Déconnexion",
            subtitle: "Se déconnecter de l'app",
            color: Colors.orange,
            onTap: _signOut,
            theme: theme,
          ),
          _buildDivider(isDark),
          _buildDangerTile(
            icon: Icons.delete_forever_rounded,
            title: "Supprimer le compte",
            subtitle: "Action irréversible",
            color: Colors.red,
            onTap: _deleteAccount,
            theme: theme,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Le Bon Taxi",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodySmall?.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Fait avec ❤️ en Haïti",
            style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
