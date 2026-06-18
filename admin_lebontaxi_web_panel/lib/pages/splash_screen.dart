import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/side_navigation_drawer.dart';
import 'login_page.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // ─── Animation Controllers ─────────────────────────────────
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _haloCtrl;
  late AnimationController _exitCtrl;

  // ─── Animations ────────────────────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _haloScale;
  late Animation<double> _haloPulse;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _progressFade;
  late Animation<double> _exitFade;

  // ─── Particles ─────────────────────────────────────────────
  final List<_Particle> _particles = [];
  final _random = Random();

  // ─── Auth ──────────────────────────────────────────────────
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _initAnimations();
    _startAnimationSequence();

    // ✅ Écouter les changements d'auth (pour le retour OAuth Google)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        print("✅ OAuth callback détecté — session établie");
        _authSubscription?.cancel();
        _navigateAfterAuth(data.session!.user);
      }
    });

    // Check authentication status and navigate
    _checkAuthAndNavigate();
  }

  void _initParticles() {
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.6 + 0.1,
        drift: (_random.nextDouble() - 0.5) * 0.15,
      ));
    }
  }

  void _initAnimations() {
    // Background gradient animation (continuous)
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Particle animation (continuous)
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Logo entrance
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    // Halo pulse (continuous after logo appears)
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _haloScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut),
    );
    _haloPulse = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut),
    );

    // Text entrance
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    // Progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    // Exit animation
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic),
    );
  }

  Future<void> _startAnimationSequence() async {
    // Step 1: Logo entrance
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoCtrl.forward();

    // Step 2: Halo pulse starts
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _haloCtrl.repeat(reverse: true);

    // Step 3: Text slides in
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textCtrl.forward();

    // Step 4: Progress bar appears
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _progressCtrl.forward();
  }

  // ─── AUTH LOGIC (Preserved exactly as original) ────────────

  /// Navigation après authentification réussie (email/password ou OAuth)
  Future<void> _navigateAfterAuth(User user) async {
    try {
      if (user.email == null) throw Exception("Email missing");
      
      final adminCheck = await Supabase.instance.client.from('admins').select().eq('email', user.email!).limit(1);
      
      if (adminCheck.isNotEmpty) {
        if (mounted) {
          await _exitCtrl.forward();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SideNavigationDrawer()),
          );
        }
        return;
      }

      // Si la table admin est vide (première config), on s'ajoute
      final allAdmins = await Supabase.instance.client.from('admins').select().limit(1);
      if (allAdmins.isEmpty) {
        await Supabase.instance.client.from('admins').insert({'email': user.email});
        if (mounted) {
          await _exitCtrl.forward();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SideNavigationDrawer()),
          );
        }
        return;
      }
      
      // L'utilisateur n'est pas un admin
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Accès refusé. Vous n'êtes pas administrateur."), backgroundColor: Colors.red),
        );
        await _exitCtrl.forward();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        await _exitCtrl.forward();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    // Navigate snappily since the HTML splash screen has already been shown
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Check if user is already logged in
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      await _navigateAfterAuth(user);
    } else {
      // User is not logged in, go to login page
      await _exitCtrl.forward();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _progressCtrl.dispose();
    _bgCtrl.dispose();
    _particleCtrl.dispose();
    _haloCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _exitFade,
        child: Stack(
          children: [
            // Animated gradient background
            _buildAnimatedBackground(sz),

            // Floating particles
            _buildParticles(sz),

            // Grid pattern overlay
            _buildGridOverlay(sz),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Logo with halo
                  _buildLogoWithHalo(),

                  const SizedBox(height: 48),

                  // Title
                  _buildTitle(),

                  const SizedBox(height: 12),

                  // Subtitle
                  _buildSubtitle(),

                  const Spacer(flex: 2),

                  // Progress bar
                  _buildProgressBar(sz),

                  const SizedBox(height: 16),

                  // Loading text
                  _buildLoadingText(),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ANIMATED GRADIENT BACKGROUND ──────────────────────────

  Widget _buildAnimatedBackground(Size sz) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Container(
          width: sz.width,
          height: sz.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + sin(t * 2 * pi) * 0.5,
                -1.0 + cos(t * 2 * pi) * 0.3,
              ),
              end: Alignment(
                1.0 + cos(t * 2 * pi) * 0.5,
                1.0 + sin(t * 2 * pi) * 0.3,
              ),
              colors: [
                Color.lerp(
                  const Color(0xFF060B18),
                  const Color(0xFF0F1B3D),
                  (sin(t * 2 * pi) + 1) / 2,
                )!,
                Color.lerp(
                  const Color(0xFF0A0F20),
                  const Color(0xFF1A0F30),
                  (cos(t * 2 * pi) + 1) / 2,
                )!,
                Color.lerp(
                  const Color(0xFF060B18),
                  const Color(0xFF15102A),
                  (sin(t * 2 * pi + 1) + 1) / 2,
                )!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Orb 1 — Gold (top-left)
              Positioned(
                top: sz.height * 0.15 + sin(t * 2 * pi) * 40,
                left: sz.width * 0.1 + cos(t * 2 * pi * 0.7) * 30,
                child: _buildOrb(260, const Color(0xFFFBBF24), 0.06),
              ),
              // Orb 2 — Indigo (bottom-right)
              Positioned(
                bottom: sz.height * 0.1 + cos(t * 2 * pi) * 35,
                right: sz.width * 0.12 + sin(t * 2 * pi * 0.8) * 25,
                child: _buildOrb(320, const Color(0xFF6366F1), 0.05),
              ),
              // Orb 3 — Violet (top-right)
              Positioned(
                top: sz.height * 0.25 + sin(t * 2 * pi * 0.6 + 2) * 30,
                right: sz.width * 0.2 + cos(t * 2 * pi * 0.5) * 40,
                child: _buildOrb(200, const Color(0xFF8B5CF6), 0.04),
              ),
              // Orb 4 — Cyan (bottom-left)
              Positioned(
                bottom: sz.height * 0.25 + cos(t * 2 * pi * 0.9 + 1) * 25,
                left: sz.width * 0.15 + sin(t * 2 * pi * 0.6) * 35,
                child: _buildOrb(180, const Color(0xFF06B6D4), 0.035),
              ),
              // Orb 5 — Gold center (behind logo)
              Positioned(
                top: sz.height * 0.35 + sin(t * 2 * pi * 0.4) * 15,
                left: sz.width * 0.35,
                child: _buildOrb(sz.width * 0.3, const Color(0xFFFBBF24), 0.03),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.5),
            color.withOpacity(0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }

  // ─── FLOATING PARTICLES ────────────────────────────────────

  Widget _buildParticles(Size sz) {
    return AnimatedBuilder(
      animation: _particleCtrl,
      builder: (_, __) {
        return CustomPaint(
          size: sz,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _particleCtrl.value,
          ),
        );
      },
    );
  }

  // ─── GRID OVERLAY ──────────────────────────────────────────

  Widget _buildGridOverlay(Size sz) {
    return Opacity(
      opacity: 0.03,
      child: CustomPaint(
        size: sz,
        painter: _GridPainter(),
      ),
    );
  }

  // ─── LOGO WITH HALO ───────────────────────────────────────

  Widget _buildLogoWithHalo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoCtrl, _haloCtrl]),
      builder: (_, __) {
        return FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo glow
                  Transform.scale(
                    scale: _haloCtrl.isAnimating ? _haloScale.value : 1.0,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFBBF24).withOpacity(
                              _haloCtrl.isAnimating ? _haloPulse.value : 0.15,
                            ),
                            const Color(0xFFFBBF24).withOpacity(0.05),
                            const Color(0xFFFBBF24).withOpacity(0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Glassmorphism container
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFBBF24).withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipOval(
                            child: Image.asset(
                              'images/lebontaxi.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_taxi,
                                size: 60,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TITLE ─────────────────────────────────────────────────

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _titleSlide.value),
          child: Opacity(
            opacity: _titleFade.value,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.white,
                  Color(0xFFFBBF24),
                  Colors.white,
                ],
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: Text(
                "Le Bon Taxi",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── SUBTITLE ──────────────────────────────────────────────

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _subtitleSlide.value),
          child: Opacity(
            opacity: _subtitleFade.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withOpacity(0.3),
                  width: 1,
                ),
                color: const Color(0xFFFBBF24).withOpacity(0.08),
              ),
              child: Text(
                "ADMIN PANEL",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFBBF24).withOpacity(0.9),
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── PROGRESS BAR ──────────────────────────────────────────

  Widget _buildProgressBar(Size sz) {
    return AnimatedBuilder(
      animation: Listenable.merge([_progressCtrl, _bgCtrl]),
      builder: (_, __) {
        return Opacity(
          opacity: _progressFade.value,
          child: Column(
            children: [
              SizedBox(
                width: min(300, sz.width * 0.6),
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      // Track
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: _progressCtrl.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFBBF24),
                                Color(0xFFF59E0B),
                                Color(0xFFFBBF24),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFBBF24).withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Shimmer sweep on the progress bar
                      FractionallySizedBox(
                        widthFactor: _progressCtrl.value,
                        child: AnimatedBuilder(
                          animation: _bgCtrl,
                          builder: (_, __) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                final sweep = (_bgCtrl.value * 3) % 1.0;
                                return LinearGradient(
                                  begin: Alignment(-1.0 + sweep * 3, 0),
                                  end: Alignment(-0.5 + sweep * 3, 0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcATop,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── LOADING TEXT ──────────────────────────────────────────

  Widget _buildLoadingText() {
    return AnimatedBuilder(
      animation: _progressCtrl,
      builder: (_, __) {
        return Opacity(
          opacity: _progressFade.value,
          child: Text(
            "Chargement de votre espace…",
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

// ─── PARTICLE MODEL ────────────────────────────────────────

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double drift;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });
}

// ─── PARTICLE PAINTER ──────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Calculate position — particles float upward and loop
      final y = (p.y - progress * p.speed) % 1.0;
      final x = p.x + sin(progress * 2 * pi + p.drift * 10) * 0.02;

      final paint = Paint()
        ..color = const Color(0xFFFBBF24).withOpacity(p.opacity * (0.5 + 0.5 * sin(progress * 2 * pi * p.speed)))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.5);

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

// ─── GRID PAINTER ──────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
