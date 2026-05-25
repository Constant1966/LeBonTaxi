import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/biometric_service.dart';
import 'package:drivers_app/services/sync_service.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:drivers_app/services/subscription_service.dart';
import 'package:drivers_app/services/app_settings_service.dart';
import 'package:drivers_app/authentication/login_screen.dart';
import 'package:drivers_app/authentication/driver_registration_screen.dart';
import 'package:drivers_app/pages/dashboard.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/global/global_var.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  // ── Animations ──
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotation;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _pulseFade;

  bool _hasError = false;
  String _errorMessage = "";
  bool _showBiometricPrompt = false;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
    _initializeApp();
  }

  void _setupAnimations() {
    // ── Logo animation (0-1500ms): scale + fade + subtle rotation ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

    _logoRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // ── Text animation (400ms delay): slide up + fade ──
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // ── Shimmer animation (infinite) ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ── Pulse glow animation (infinite) ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseFade = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimationSequence() async {
    // Start logo animation
    _logoController.forward();

    // Start text after 400ms delay
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _textController.forward();

    // Start shimmer loop after logo appears
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _shimmerController.repeat();

    // Start pulse glow
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      _checkAuth();
    } catch (e) {
      print("❌ Erreur initialisation: $e");
      setState(() {
        _hasError = true;
        _errorMessage = "Erreur d'initialisation: $e";
      });
    }
  }

  Future<void> _checkAuth() async {
    try {
      final isOnline = await SyncService.isOnline();
      final user = SupabaseService.getCurrentUser();

      if (user == null) {
        if (!isOnline) {
          await _tryOfflineMode();
          return;
        }
        _goToLogin();
        return;
      }

      print('✅ User connecté: ${user.id}');

      Map<String, dynamic>? driverProfile;

      if (isOnline) {
        driverProfile = await SupabaseService.getDriverProfile(user.id);

        if (driverProfile == null) {
          await SupabaseService.createDriverProfile(
            email: user.email ?? '',
            name: user.userMetadata?['name'] ?? user.email ?? 'Chauffeur',
            photo: user.userMetadata?['picture'],
          );
          _goToRegistration();
          return;
        }

        await LocalDatabaseService.saveDriverProfile(driverProfile);
        SyncService.syncTripsHistory();
        SyncService.syncEarnings();
      } else {
        driverProfile = await LocalDatabaseService.getDriverProfile(user.id);
        driverProfile ??= await LocalDatabaseService.getAnyDriverProfile();

        if (driverProfile == null) {
          setState(() {
            _hasError = true;
            _errorMessage =
                "Pas de connexion internet et aucun profil en cache. "
                "Connectez-vous à Internet pour vous identifier.";
          });
          return;
        }

        _isOfflineMode = true;
        print('📴 Mode hors-ligne — données du cache');
      }

      _loadDriverData(driverProfile);

      final blockStatus = driverProfile['block_status'] ?? 'no';
      final verified = driverProfile['verified'] ?? false;
      final profileCompleted = driverProfile['profile_completed'] ?? false;

      if (blockStatus == 'yes') {
        _showBlockedDialog();
        return;
      }

      if (!profileCompleted) {
        if (_isOfflineMode) {
          setState(() {
            _hasError = true;
            _errorMessage =
                "Votre profil est incomplet. Connectez-vous à Internet pour le compléter.";
          });
          return;
        }
        _goToRegistration();
        return;
      }

      if (!verified && !_isOfflineMode) {
        _showNotVerifiedDialog();
        return;
      }

      // Charger abonnement et paramètres de tarification
      await _loadSubscriptionAndSettings();

      await _checkBiometricAuth();
    } catch (e) {
      print('❌ Erreur splash: $e');
      _goToLogin();
    }
  }

  Future<void> _tryOfflineMode() async {
    final cachedProfile = await LocalDatabaseService.getAnyDriverProfile();

    if (cachedProfile == null) {
      _goToLogin();
      return;
    }

    _loadDriverData(cachedProfile);
    _isOfflineMode = true;

    final profileCompleted = cachedProfile['profile_completed'] ?? false;
    final verified = cachedProfile['verified'] ?? false;

    if (!profileCompleted || !verified) {
      setState(() {
        _hasError = true;
        _errorMessage =
            "Pas de connexion Internet. Impossible de vérifier votre compte.";
      });
      return;
    }

    await _checkBiometricAuth();
  }

  Future<void> _checkBiometricAuth() async {
    final biometricEnabled = await BiometricService.isBiometricEnabled();
    final biometricAvailable = await BiometricService.isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      setState(() => _showBiometricPrompt = true);

      final authenticated = await BiometricService.authenticate(
        reason: 'Authentifiez-vous pour accéder à Le Bon Taxi',
      );

      if (authenticated) {
        _goToDashboard();
      } else {
        setState(() => _showBiometricPrompt = false);
        _showBiometricFailedDialog();
      }
    } else {
      _goToDashboard();
    }
  }

  void _loadDriverData(Map<String, dynamic> profile) {
    driverId = profile['id'] ?? '';
    driverName = profile['name'] ?? '';
    driverPhone = profile['phone'] ?? '';
    driverPhoto = profile['photo'] ?? '';
    driverEmail = profile['email'] ?? '';
    carModel = profile['car_model'] ?? '';
    carColor = profile['car_color'] ?? '';
    carNumber = profile['car_number'] ?? '';
    carYear = profile['car_year'] ?? '';
    carFrontPhoto = profile['car_front_photo'] ?? '';
    carBackPhoto = profile['car_back_photo'] ?? '';
    carSidePhoto = profile['car_side_photo'] ?? '';
    fcmToken = profile['fcm_token'] ?? '';
    isDriverCurrentlyOnline = profile['is_available'] ?? false;
  }

  /// Charger le statut d'abonnement et les paramètres de tarification
  Future<void> _loadSubscriptionAndSettings() async {
    try {
      // Charger les paramètres de tarification (toujours)
      await AppSettingsService.loadSettings();
      print('✅ Paramètres de tarification chargés');

      // Charger le statut d'abonnement du chauffeur
      if (driverId.isNotEmpty) {
        final subscription = await SubscriptionService.getActiveSubscription(driverId);
        if (subscription != null && subscription.isActive) {
          isDriverSubscribed = true;
          currentSubscriptionPlanName = subscription.planName;
          driverDiscountPercent = subscription.discountPercentage ?? 0.0;
          subscriptionExpiresAt = subscription.endDate;
          print('✅ Abonnement actif: ${subscription.planName} (expire: ${subscription.endDate})');
        } else {
          isDriverSubscribed = false;
          currentSubscriptionPlanName = null;
          driverDiscountPercent = 0.0;
          subscriptionExpiresAt = null;
          print('ℹ️ Pas d\'abonnement actif');
        }
      }
    } catch (e) {
      print('⚠️ Erreur chargement abonnement/paramètres: $e');
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _goToRegistration() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DriverRegistrationScreen(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Dashboard(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _showBlockedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Compte Bloqué')),
          ],
        ),
        content: const Text(
          'Votre compte a été bloqué. Contactez le support pour plus d\'informations.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService.signOut();
              clearDriverData();
              if (mounted) Navigator.pop(context);
              _goToLogin();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotVerifiedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('En attente de vérification')),
          ],
        ),
        content: const Text(
          'Votre compte est en cours de vérification. Vous recevrez une notification dans 24-48h.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService.signOut();
              clearDriverData();
              if (mounted) Navigator.pop(context);
              _goToLogin();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBiometricFailedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: AppColors.primary, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Authentification requise')),
          ],
        ),
        content: const Text(
          'L\'authentification biométrique a échoué. Veuillez réessayer ou connectez-vous autrement.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService.signOut();
              clearDriverData();
              _goToLogin();
            },
            child: const Text('Se connecter autrement'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBiometricAuth();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = "";
      _showBiometricPrompt = false;
      _isOfflineMode = false;
    });
    _logoController.reset();
    _textController.reset();
    _startAnimationSequence();
    _initializeApp();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorScreen();

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
            // ── Background decorative elements ──
            _buildBackgroundDecorations(),

            // ── Main content ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ── Logo with glow ──
                  _buildAnimatedLogo(),

                  const SizedBox(height: 40),

                  // ── App title ──
                  _buildAnimatedTitle(),

                  const Spacer(flex: 2),

                  // ── Loading / biometric indicator ──
                  if (_showBiometricPrompt)
                    _buildBiometricIndicator()
                  else
                    _buildLoadingIndicator(),

                  // ── Offline badge ──
                  if (_isOfflineMode) ...[
                    const SizedBox(height: 16),
                    _buildOfflineBadge(),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BACKGROUND DECORATIONS
  // ============================================================

  Widget _buildBackgroundDecorations() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-right golden circle
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
                      const Color(0xFFD4A574).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left golden circle
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
                      const Color(0xFFB8860B).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Center subtle radial glow
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseFade,
                  builder: (context, _) {
                    return Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFD4A574)
                                .withValues(alpha: _pulseFade.value * 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ANIMATED LOGO
  // ============================================================

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScale.value,
          child: Transform.rotate(
            angle: _logoRotation.value,
            child: Opacity(
              opacity: _logoFade.value,
              child: child,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer golden glow ring
          AnimatedBuilder(
            animation: _pulseFade,
            builder: (context, _) {
              return Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4A574)
                        .withValues(alpha: _pulseFade.value * 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A574)
                          .withValues(alpha: _pulseFade.value * 0.15),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              );
            },
          ),
          // Logo container
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/lebontaxi_compressed.png',
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_taxi,
                        size: 80, color: AppColors.primary),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANIMATED TITLE
  // ============================================================

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _textSlide.value),
          child: child,
        );
      },
      child: Column(
        children: [
          // Main title
          FadeTransition(
            opacity: _textFade,
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFFD4A574), // Gold
                    Color(0xFFF5E6D3), // Light gold
                    Color(0xFFD4A574), // Gold
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: const Text(
                'LE BON TAXI',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                  height: 1.2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          FadeTransition(
            opacity: _subtitleFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.4),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ESPACE CHAUFFEUR',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFD4A574),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING INDICATOR
  // ============================================================

  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _subtitleFade,
      child: Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFD4A574).withValues(alpha: 0.7),
              ),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BIOMETRIC
  // ============================================================

  Widget _buildBiometricIndicator() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseFade,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A574)
                      .withValues(alpha: _pulseFade.value * 0.5),
                  width: 2,
                ),
              ),
              child: child,
            );
          },
          child: const Icon(Icons.fingerprint, size: 48, color: Color(0xFFD4A574)),
        ),
        const SizedBox(height: 16),
        Text(
          'Authentification en cours...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OFFLINE BADGE
  // ============================================================

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text(
            'Mode hors-ligne',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR SCREEN
  // ============================================================

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Une erreur s'est produite",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A574),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    elevation: 8,
                    shadowColor: const Color(0xFFD4A574).withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    "Réessayer",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}