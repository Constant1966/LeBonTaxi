import 'package:flutter/material.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/google_signin_service.dart';
import 'package:drivers_app/authentication/driver_registration_screen.dart';
import 'package:drivers_app/pages/dashboard.dart';
import 'package:drivers_app/pages/document_status_page.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/utils/responsive_helper.dart';
import 'package:drivers_app/services/local_database_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _contentController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotation;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;
  late Animation<double> _pulseFade;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoRotation = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseFade = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _contentController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
              Color(0xFF0F172A), // Slate 900
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background decorations ──
            _buildBackgroundDecorations(),

            // ── Main content ──
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.horizontalPadding(context),
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _buildAnimatedLogo(),
                        const SizedBox(height: 40),
                        _buildAnimatedTitle(),
                        const SizedBox(height: 64),
                        _buildSignInButton(),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background decorations ─────────────────────────────────────────────────

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4A574).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFB8860B).withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseFade,
              builder: (context, _) => Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD4A574)
                          .withOpacity(_pulseFade.value * 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Animated logo ──────────────────────────────────────────────────────────

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) => Transform.scale(
        scale: _logoScale.value,
        child: Transform.rotate(
          angle: _logoRotation.value,
          child: Opacity(opacity: _logoFade.value, child: child),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          AnimatedBuilder(
            animation: _pulseFade,
            builder: (context, _) => Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A574)
                      .withOpacity(_pulseFade.value * 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4A574)
                        .withOpacity(_pulseFade.value * 0.15),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Logo
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A574).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/lebontaxi_compressed.png',
                width: 170,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_taxi,
                      size: 80, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated title ─────────────────────────────────────────────────────────

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _contentSlide.value),
        child: Opacity(opacity: _contentFade.value, child: child),
      ),
      child: Column(
        children: [
          // Golden gradient title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFD4A574),
                Color(0xFFF5E6D3),
                Color(0xFFD4A574),
              ],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: const Text(
              'LE BON TAXI',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFD4A574).withOpacity(0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ESPACE CHAUFFEUR',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFD4A574),
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign in button ─────────────────────────────────────────────────────────

  Widget _buildSignInButton() {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _contentSlide.value * 1.2),
        child: Opacity(opacity: _contentFade.value, child: child),
      ),
      child: _isLoading
          ? Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFD4A574).withOpacity(0.8),
              ),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connexion en cours...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      )
          : GestureDetector(
        onTap: _handleGoogleSignIn,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD4A574).withOpacity(0.15),
                const Color(0xFFB8860B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4A574).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4A574).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/google-sign.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Continuer avec Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4A574),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) =>
          Opacity(opacity: _contentFade.value, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A574).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFFD4A574),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Connectez-vous avec votre compte Google pour accéder à votre espace chauffeur.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Google Sign-In logic ───────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // 1. Google Sign-In
      final googleResult = await GoogleSignInService.signIn();
      if (googleResult == null || googleResult['success'] != true) {
        _showError('Connexion Google annulée');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Supabase Auth
      final authResponse = await SupabaseService.signInWithGoogle(
        idToken: googleResult['idToken'],
        accessToken: googleResult['accessToken'],
      );
      if (authResponse.user == null) {
        _showError('Erreur Supabase Auth');
        setState(() => _isLoading = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Récupérer ou créer le profil
      var driverProfile =
      await SupabaseService.getDriverProfile(authResponse.user!.id);

      if (driverProfile == null) {
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
        await Future.delayed(const Duration(milliseconds: 500));
        driverProfile =
        await SupabaseService.getDriverProfile(authResponse.user!.id);
        if (driverProfile == null) {
          _showError('Erreur de synchronisation. Reconnectez-vous.');
          await SupabaseService.signOut();
          setState(() => _isLoading = false);
          return;
        }
      }

      // 4. Vérifications statut
      final blockStatus = driverProfile['block_status'] ?? 'no';
      final verified = driverProfile['verified'] ?? false;
      final profileCompleted = driverProfile['profile_completed'] ?? false;
      final documentStatus =
          driverProfile['document_status']?.toString() ?? 'pending';

      // Bloqué
      if (blockStatus == 'yes') {
        await SupabaseService.signOut();
        _showStatusDialog(
          icon: Icons.block,
          iconColor: Colors.red,
          title: 'Compte bloqué',
          message:
          'Votre compte a été bloqué. Contactez le support au +509 46 89 49 05.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Profil incomplet → inscription
      if (!profileCompleted) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const DriverRegistrationScreen()),
        );
        return;
      }

      // ── Vérification document_status ─────────────────────────────────────

      switch (documentStatus) {
        case 'pending':
        case 'under_review':
        // ❌ Bloquer la connexion — en attente de vérification admin
          await SupabaseService.signOut();
          _showStatusDialog(
            icon: Icons.hourglass_top,
            iconColor: Colors.orange,
            title: 'Vérification en cours',
            message:
            'Votre dossier est en cours d\'examen par notre équipe.\n\nVous recevrez un email dès que votre dossier sera traité (24-48h).',
          );
          setState(() => _isLoading = false);
          return;

        case 'documents_required':
        // Rediriger vers l'inscription pour compléter les documents
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const DriverRegistrationScreen()),
          );
          return;

        case 'rejected':
        // ❌ Bloquer mais permettre de voir les documents
          _showRejectedDialog(driverProfile);
          setState(() => _isLoading = false);
          return;

        case 'approved':
          if (!verified) {
            // Approuvé mais pas encore marqué verified → forcer la mise à jour
            await SupabaseService.updateDriverProfile({'verified': true});
          }
          // ✅ Continuer vers le dashboard
          break;

        default:
          await SupabaseService.signOut();
          _showStatusDialog(
            icon: Icons.hourglass_top,
            iconColor: Colors.orange,
            title: 'Vérification en cours',
            message:
            'Votre dossier est en cours de traitement. Vous serez notifié par email.',
          );
          setState(() => _isLoading = false);
          return;
      }

      // ✅ Tout est OK → Dashboard
      // ✅ Déjà un compte, pas besoin de montrer le guide
      await LocalDatabaseService.saveAppSetting('has_completed_guide', 'true');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    } catch (e) {
      print('❌ Erreur login: $e');
      _showError('Erreur de connexion: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showStatusDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFFD4A574), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog(Map<String, dynamic> profile) {
    if (!mounted) return;
    final rejectionNote =
        profile['documents_rejection_note']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
              const Icon(Icons.cancel, color: Colors.red, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Documents rejetés',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Un ou plusieurs de vos documents n\'ont pas été validés.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5),
            ),
            if (rejectionNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Motif :',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    const SizedBox(height: 4),
                    Text(rejectionNote,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Ouvrez l\'app pour re-soumettre les documents concernés.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const DocumentStatusPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Voir mes documents'),
          ),
        ],
      ),
    );
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
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}