import 'package:flutter/material.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/google_signin_service.dart';
import 'package:drivers_app/authentication/driver_registration_screen.dart';
import 'package:drivers_app/pages/dashboard.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.horizontalPadding(context),
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo avec animation
                      _buildAnimatedLogo(),

                      const SizedBox(height: 48),

                      // Titre
                      const Text(
                        'Le Bon Taxi',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 8,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Sous-titre
                      const Text(
                        'Espace Chauffeur',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 80),

                      // Bouton Google Sign-In
                      _isLoading
                          ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      )
                          : _buildGoogleSignInButton(),

                      const SizedBox(height: 48),

                      // Message d'info moderne
                      _buildInfoCard(),
                    ],
                  ),
                ),
              ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/final_logo.png',
              width: 110,
              height: 110,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.local_taxi,
                  size: 110,
                  color: AppColors.primary,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleSignInButton() {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: _handleGoogleSignIn,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google-sign.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.g_mobiledata,
                    size: 36,
                    color: Colors.blue,
                  );
                },
              ),
              const SizedBox(width: 16),
              const Text(
                'Continuer avec Google',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Connectez-vous avec votre compte Google pour commencer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      print('🔐 Démarrage Google Sign-In...');

      // 1. Google Sign-In
      final googleResult = await GoogleSignInService.signIn();

      if (googleResult == null || googleResult['success'] != true) {
        _showError('Connexion Google annulée');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Google Sign-In réussi: ${googleResult['email']}');

      // 2. Sign in Supabase avec Google tokens
      final authResponse = await SupabaseService.signInWithGoogle(
        idToken: googleResult['idToken'],
        accessToken: googleResult['accessToken'],
      );

      if (authResponse.user == null) {
        _showError('Erreur Supabase Auth');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Supabase Auth réussi: ${authResponse.user!.id}');

      // Attendre 500ms pour laisser le trigger se déclencher
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Vérifier si le profil chauffeur existe
      var driverProfile = await SupabaseService.getDriverProfile(
        authResponse.user!.id,
      );

      if (driverProfile == null) {
        print('📝 Profil inexistant, création...');

        // Créer le profil
        final created = await SupabaseService.createDriverProfile(
          email: googleResult['email'],
          name: googleResult['name'],
          photo: googleResult['photo'],
        );

        if (!created) {
          _showError('Impossible de créer le profil. Réessayez.');
          setState(() => _isLoading = false);
          return;
        }

        // Attendre que le profil soit créé
        await Future.delayed(const Duration(milliseconds: 500));

        // Re-vérifier
        driverProfile = await SupabaseService.getDriverProfile(
          authResponse.user!.id,
        );

        if (driverProfile == null) {
          _showError('Erreur de synchronisation. Reconnectez-vous.');
          await SupabaseService.signOut();
          setState(() => _isLoading = false);
          return;
        }
      }

      print('✅ Profil trouvé: ${driverProfile['email']}');

      // 4. Vérifier le status du profil
      final blockStatus = driverProfile['block_status'] ?? 'no';
      final verified = driverProfile['verified'] ?? false;
      final profileCompleted = driverProfile['profile_completed'] ?? false;

      // Bloqué
      if (blockStatus == 'yes') {
        await SupabaseService.signOut();
        _showError(
          'Votre compte a été bloqué. Contactez le support.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Profil incomplet
      if (!profileCompleted) {
        print('📋 Profil incomplet, redirection vers registration');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverRegistrationScreen(),
          ),
        );
        return;
      }

      // Pas vérifié
      if (!verified) {
        await SupabaseService.signOut();
        _showDialog(
          title: 'Vérification en cours',
          message:
          'Votre compte est en cours de vérification. Vous recevrez une notification dans 24-48h.',
          isError: false,
        );
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Tout est OK → Dashboard
      print('✅ Tout OK, redirection vers Dashboard');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Dashboard(),
        ),
      );
    } catch (e) {
      print('❌ Erreur login: $e');
      _showError('Erreur de connexion: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDialog({
    required String title,
    required String message,
    bool isError = true,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red : AppColors.info,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}