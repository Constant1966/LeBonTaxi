import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:users_app/authentication/login_screen_supabase.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/pages/settings_page.dart';
import 'package:users_app/pages/trips_history_page_supabase.dart';
import 'package:users_app/pages/about_page.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/global/global_var_supabase.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  // Données utilisateur
  String _photoUrl = "";
  String _userName = "";
  String _userEmail = "";
  String _userPhone = "";
  int _totalTrips = 0;
  double _totalDistance = 0;
  String _memberSince = "";

  // États
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isLoggingOut = false;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<_QuickAction> _quickActions = const [
    _QuickAction(
      icon: Icons.history,
      title: 'Historique',
      subtitle: 'Vos courses',
      color: AppColors.primary,
    ),
    _QuickAction(
      icon: Icons.settings,
      title: 'Paramètres',
      subtitle: 'Préférences',
      color: AppColors.secondary,
    ),
    _QuickAction(
      icon: Icons.info_outline,
      title: 'À propos',
      subtitle: 'Application',
      color: AppColors.accent,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserData();
  }


  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      if (!SupabaseService.isAuthenticated) {
        setState(() => _isLoading = false);
        return;
      }

      await Future.wait([
        _loadUserProfile(),
        _loadUserStats(),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ Erreur chargement données: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await SupabaseService.getUserProfile();

      if (profile != null && mounted) {
        setState(() {
          _userName = profile['name'] ?? 'Utilisateur';
          _userEmail = profile['email'] ?? '';
          _userPhone = profile['phone'] ?? '';
          _photoUrl = profile['photo'] ?? '';
          _memberSince = profile['created_at'] ?? DateTime.now().toIso8601String();
        });
      }
    } catch (e) {
      print("❌ Erreur profil: $e");
    }
  }

  Future<void> _loadUserStats() async {
    try {
      if (!SupabaseService.isAuthenticated) return;

      // Récupérer toutes les courses terminées de l'utilisateur
      final trips = await SupabaseService.supabase
          .from('trip_requests')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .eq('status', 'ended');

      if (mounted) {
        int tripCount = trips.length;
        double totalDistance = 0;

        for (var trip in trips) {
          if (trip['distance'] != null) {
            // Extraire le nombre de la string "X km"
            String distStr = trip['distance'].toString();
            double dist = double.tryParse(distStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
            totalDistance += dist;
          }
        }

        setState(() {
          _totalTrips = tripCount;
          _totalDistance = totalDistance;
        });
      }
    } catch (e) {
      print("❌ Erreur stats: $e");
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day} ${_getMonth(date.month)} ${date.year}";
    } catch (e) {
      return "Date inconnue";
    }
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[month - 1];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      setState(() => _isUploading = true);
      await _uploadImage(image);
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      final fileName = 'profile_${SupabaseService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload vers Supabase Storage
      final bytes = await File(image.path).readAsBytes();
      await SupabaseService.supabase.storage
          .from('user-photos')
          .uploadBinary(fileName, bytes);

      // Obtenir l'URL publique
      final photoUrl = SupabaseService.supabase.storage
          .from('user-photos')
          .getPublicUrl(fileName);

      // Mettre à jour le profil
      await SupabaseService.updateUserProfile({'photo': photoUrl});

      await _saveUserInfo(photoUrl);

      if (mounted) {
        setState(() {
          _photoUrl = photoUrl;
          _isUploading = false;
        });
        _showSuccessSnackBar("Photo mise à jour avec succès");
      }
    } catch (e) {
      print("❌ Erreur upload: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorSnackBar("Erreur: ${e.toString()}");
      }
    }
  }

  Future<void> _saveUserInfo(String photoUrl) async {
    if (_userName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_photo', photoUrl);
    await prefs.setString('last_user_name', _userName);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);
    Navigator.pop(context); // Fermer le dialog de confirmation

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLogoutLoadingDialog(),
    );

    try {
      // Nettoyer les données globales
      clearUserData();

      // Nettoyer SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Déconnexion Supabase
      await SupabaseService.signOut();

      print("✅ Déconnexion réussie");

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreenSupabase()),
        );
      }
    } catch (e) {
      print("❌ Erreur déconnexion: $e");
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isLoggingOut = false);
        _showErrorSnackBar("Erreur lors de la déconnexion");
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text("Déconnexion"),
          ],
        ),
        content: const Text(
          "Êtes-vous sûr de vouloir vous déconnecter ?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      _buildStatsCard(),
                      const SizedBox(height: 20),
                      _buildPersonalInfo(),
                      const SizedBox(height: 20),
                      ...List.generate(
                        _quickActions.length,
                            (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildActionCard(_quickActions[index]),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLogoutButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  children: [
                    _buildProfileImage(),
                    if (_isUploading) _buildUploadingOverlay(),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: _photoUrl.isNotEmpty
              ? Image.network(
            _photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
          )
              : _buildDefaultAvatar(),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white,
      child: const Icon(
        Icons.person,
        size: 50,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildUploadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.directions_car,
            value: _totalTrips.toString(),
            label: 'Courses',
            color: AppColors.primary,
          ),
          Container(
            height: 40,
            width: 1,
            color: AppColors.border,
          ),
          _buildStatItem(
            icon: Icons.straighten,
            value: '${_totalDistance.toStringAsFixed(1)} km',
            label: 'Distance',
            color: AppColors.secondary,
          ),
          Container(
            height: 40,
            width: 1,
            color: AppColors.border,
          ),
          _buildStatItem(
            icon: Icons.star,
            value: '4.8',
            label: 'Note',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations personnelles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _userEmail,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: _userPhone.isNotEmpty ? _userPhone : 'Non renseigné',
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            icon: Icons.calendar_month,
            label: 'Membre depuis',
            value: _formatDate(_memberSince),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToAction(action),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon,
                  size: 24,
                  color: action.color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: action.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _showLogoutConfirmation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 22),
            SizedBox(width: 12),
            Text(
              'SE DÉCONNECTER',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutLoadingDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              "Déconnexion en cours...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAction(_QuickAction action) {
    Widget page;
    switch (action.title) {
      case 'Historique':
        page = const TripsHistoryPageSupabase();
        break;
      case 'Paramètres':
        page = const SettingsPage();
        break;
      case 'À propos':
        page = const AboutPage();
        break;
      default:
        return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}