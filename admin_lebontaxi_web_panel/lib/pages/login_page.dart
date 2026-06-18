import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/side_navigation_drawer.dart';

// ─── Floating Particle Painter ───
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.animValue});
  final List<_Particle> particles;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = (animValue + p.offset) % 1.0;
      final y = size.height * (1.0 - progress);
      final x = p.baseX * size.width + sin(progress * pi * 2 * p.freq) * p.amplitude;
      final opacity = (1.0 - (1.0 - progress).abs()) * p.maxOpacity;
      final fadedOpacity = opacity * (progress < 0.1 ? progress / 0.1 : (progress > 0.85 ? (1.0 - progress) / 0.15 : 1.0));
      final paint = Paint()
        ..color = p.color.withOpacity(fadedOpacity.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 0.5);
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

class _Particle {
  final double baseX;
  final double offset;
  final double freq;
  final double amplitude;
  final double radius;
  final double maxOpacity;
  final Color color;

  _Particle({
    required this.baseX,
    required this.offset,
    required this.freq,
    required this.amplitude,
    required this.radius,
    required this.maxOpacity,
    required this.color,
  });
}

// ─── Grid Overlay Painter ───
class _GridPainter extends CustomPainter {
  _GridPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 0.3;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.opacity != opacity;
}

class LoginPage extends StatefulWidget {
  final bool showInactivityMessage;
  const LoginPage({super.key, this.showInactivityMessage = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _registering = false;

  late AnimationController _pulseCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _brandSlide;
  late Animation<double> _brandFade;
  late Animation<double> _formSlide;
  late Animation<double> _formFade;

  Offset _mouse = Offset.zero;
  late List<_Particle> _particles;
  bool _googleHover = false;

  @override
  void initState() {
    super.initState();

    if (widget.showInactivityMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _snack("Vous avez été déconnecté suite à une longue période d'inactivité.", true);
      });
    }

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 10000))..repeat();

    // Brand panel entrance: slide from left + fade in
    _brandSlide = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _brandFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    // Form panel entrance: slide up + fade in
    _formSlide = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic)),
    );
    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.25, 0.75, curve: Curves.easeOut)),
    );

    // Generate particles
    final rng = Random(42);
    _particles = List.generate(25, (_) {
      final colors = [
        const Color(0xFFFBBF24),
        const Color(0xFFFFD700),
        const Color(0xFFF59E0B),
        Colors.white,
      ];
      return _Particle(
        baseX: rng.nextDouble(),
        offset: rng.nextDouble(),
        freq: 1.0 + rng.nextDouble() * 2.0,
        amplitude: 8.0 + rng.nextDouble() * 25.0,
        radius: 1.2 + rng.nextDouble() * 2.5,
        maxOpacity: 0.15 + rng.nextDouble() * 0.45,
        color: colors[rng.nextInt(colors.length)],
      );
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ─── AUTH ───

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      final sb = Supabase.instance.client;

      if (_registering) {
        final res = await sb.auth.signUp(email: email, password: password);
        if (res.user != null) {
          try { await sb.from('admins').insert({'email': email}); } catch (_) {}
          if (mounted) _snack('Compte créé !', false);
        }
      } else {
        final res = await sb.auth.signInWithPassword(email: email, password: password);
        if (res.user != null) {
          try {
            final check = await sb.from('admins').select().eq('email', email);
            if (check.isEmpty) {
              final all = await sb.from('admins').select().limit(1);
              if (all.isEmpty) {
                await sb.from('admins').insert({'email': email});
              } else {
                await sb.auth.signOut();
                throw Exception("Accès refusé. Vous n'êtes pas administrateur.");
              }
            }
          } catch (e) {
            if (e.toString().contains("Accès refusé")) rethrow;
          }
        }
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SideNavigationDrawer()),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Erreur';
        if (e is AuthException) {
          msg = e.message.toLowerCase().contains("already registered")
              ? "Ce compte existe déjà."
              : e.message;
        } else {
          msg = e.toString().replaceAll("Exception: ", "");
        }
        _snack(msg, true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      // Détecter l'URL courante pour le redirect (localhost en dev, domaine en prod)
      final redirectUrl = Uri.base.origin;
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      if (mounted) {
        _snack(e.toString(), true);
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg, bool err) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ));
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final wide = sz.width > 960;

    return Scaffold(
      body: MouseRegion(
        onHover: (e) => setState(() => _mouse = e.position),
        child: Container(
          width: sz.width,
          height: sz.height,
          color: const Color(0xFF060B18),
          child: Stack(children: [
            // Background
            _bg(sz, wide),

            // Grid overlay
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(opacity: 0.015)),
            ),

            // Floating particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ParticlePainter(particles: _particles, animValue: _particleCtrl.value),
                ),
              ),
            ),

            // Content
            if (wide) _desktopLayout(sz) else _mobileLayout(sz),
          ]),
        ),
      ),
    );
  }

  // ─── BACKGROUND ───

  Widget _bg(Size sz, bool wide) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = _pulseCtrl.value;
        final px = wide ? ((_mouse.dx / sz.width) - 0.5) * -15 : 0.0;
        final py = wide ? ((_mouse.dy / sz.height) - 0.5) * -15 : 0.0;

        return Stack(children: [
          // Photo bg
          Transform.translate(
            offset: Offset(px, py),
            child: Transform.scale(
              scale: 1.06,
              child: SizedBox.expand(
                child: Image.asset('images/download.jpg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
          ),
          // Dark gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF060B18).withValues(alpha: 0.95),
                  const Color(0xFF060B18).withValues(alpha: 0.85),
                  const Color(0xFF060B18).withValues(alpha: 0.97),
                ],
              ),
            ),
          ),
          // Animated glow orbs — 5 orbs with varied colors and movement
          Positioned(
            top: sz.height * 0.12 + sin(t * 2 * pi) * 30,
            left: sz.width * 0.06,
            child: _orb(240, const Color(0xFFFBBF24), 0.06),
          ),
          Positioned(
            bottom: sz.height * 0.08 + cos(t * 2 * pi) * 25,
            right: sz.width * 0.12,
            child: _orb(300, const Color(0xFF6366F1), 0.05),
          ),
          Positioned(
            top: sz.height * 0.55 + sin(t * 2 * pi + 1.5) * 20,
            left: sz.width * 0.35,
            child: _orb(200, const Color(0xFF8B5CF6), 0.04),
          ),
          Positioned(
            top: sz.height * 0.05 + cos(t * 2 * pi + 2.5) * 35,
            right: sz.width * 0.35,
            child: _orb(180, const Color(0xFF06B6D4), 0.04),
          ),
          Positioned(
            bottom: sz.height * 0.25 + sin(t * 2 * pi + 3.8) * 18,
            left: sz.width * 0.55,
            child: _orb(160, const Color(0xFFFFD700), 0.035),
          ),
        ]);
      },
    );
  }

  Widget _orb(double size, Color c, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)]),
    ),
  );

  // ─── DESKTOP ───

  Widget _desktopLayout(Size sz) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, __) => Row(children: [
        Expanded(
          flex: 55,
          child: Transform.translate(
            offset: Offset(_brandSlide.value, 0),
            child: Opacity(opacity: _brandFade.value, child: _brandPanel()),
          ),
        ),
        Expanded(
          flex: 45,
          child: Transform.translate(
            offset: Offset(0, _formSlide.value),
            child: Opacity(opacity: _formFade.value, child: _formPanel()),
          ),
        ),
      ]),
    );
  }

  Widget _brandPanel() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo row with glow
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset('images/lebontaxi.png', height: 36, width: 36, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.local_taxi, size: 24, color: Color(0xFF111827))),
                ),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Le Bon Taxi", style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                )),
                Text("ADMIN", style: GoogleFonts.inter(
                  color: const Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 5,
                )),
              ]),
            ]),
  
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
  
            // Hero text with gradient shader
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFFFE082), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                "Pilotez votre\nflotte en\ntemps réel.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1.5,
                  color: Colors.white,
                ),
              ),
            ),
  
            const SizedBox(height: 28),
  
            Text(
              "Tarification dynamique, gestion des chauffeurs,\nsuivi des courses — tout depuis un seul écran.",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF94A3B8),
                height: 1.8,
              ),
            ),
  
            SizedBox(height: MediaQuery.of(context).size.height * 0.04),
  
            // Feature pills (glassmorphism)
            Wrap(spacing: 12, runSpacing: 12, children: [
              _featurePill("⚡", "Temps réel"),
              _featurePill("🔒", "Sécurisé"),
              _featurePill("📊", "Analytique"),
            ]),
  
            const SizedBox(height: 36),
  
            // Animated stat counters
            Row(children: [
              _animatedStat(2500, "+", " courses"),
              const SizedBox(width: 32),
              _animatedStat(350, "+", " chauffeurs"),
              const SizedBox(width: 32),
              _animatedStatText("99.9", "% uptime"),
            ]),
  
            const SizedBox(height: 48),
  
            // Decorative faint taxi icon
            Opacity(
              opacity: 0.04,
              child: Icon(Icons.local_taxi_rounded, size: 120, color: const Color(0xFFFBBF24)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedStat(int target, String prefix, String suffix) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$prefix${value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFBBF24),
              ),
            ),
            Text(
              suffix.trim(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _animatedStatText(String number, String suffix) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 99.9),
      duration: const Duration(milliseconds: 2200),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${value.toStringAsFixed(1)}%",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFBBF24),
              ),
            ),
            Text(
              "uptime",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _featurePill(String emoji, String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(
              color: const Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500,
            )),
          ]),
        ),
      ),
    );
  }

  // ─── MOBILE ───

  Widget _mobileLayout(Size sz) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _formSlide.value),
        child: Opacity(opacity: _formFade.value, child: _formPanel(isMobile: true)),
      ),
    );
  }

  // ─── FORM ───

  Widget _formPanel({bool isMobile = false}) {
    return Center(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 56,
            vertical: isMobile ? 48 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Mobile logo
              if (isMobile) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFBBF24).withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('images/lebontaxi.png', height: 40, width: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_taxi, size: 30, color: Color(0xFF111827))),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text("LE BON TAXI", style: GoogleFonts.inter(
                  color: const Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 5,
                ))),
                const SizedBox(height: 40),
              ],

              // Glassmorphism card with animated glow border
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) {
                  final glowOpacity = 0.15 + _glowCtrl.value * 0.25;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFBBF24).withOpacity(glowOpacity * 0.3),
                          const Color(0xFF6366F1).withOpacity(glowOpacity * 0.2),
                          const Color(0xFF8B5CF6).withOpacity(glowOpacity * 0.15),
                          const Color(0xFF06B6D4).withOpacity(glowOpacity * 0.2),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(1.2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1321).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 60, offset: const Offset(0, 30)),
                              BoxShadow(
                                color: const Color(0xFFFBBF24).withOpacity(glowOpacity * 0.08),
                                blurRadius: 80,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Title with AnimatedSwitcher
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, anim) {
                                  return SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                                    child: FadeTransition(opacity: anim, child: child),
                                  );
                                },
                                child: Text(
                                  _registering ? "Créer un compte" : "Connexion",
                                  key: ValueKey<bool>(_registering),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, anim) {
                                  return FadeTransition(opacity: anim, child: child);
                                },
                                child: Text(
                                  _registering ? "Rejoignez l'administration" : "Accédez à votre tableau de bord",
                                  key: ValueKey<String>(_registering ? "reg" : "log"),
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Name (animated appearance)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                child: AnimatedOpacity(
                                  opacity: _registering ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: _registering
                                      ? Column(children: [
                                          _input(_nameCtrl, "Nom complet", Icons.person_rounded,
                                            validator: (v) => _registering && (v == null || v.isEmpty) ? 'Requis' : null),
                                          const SizedBox(height: 18),
                                        ])
                                      : const SizedBox.shrink(),
                                ),
                              ),

                              // Email
                              _input(_emailCtrl, "Adresse e-mail", Icons.alternate_email_rounded,
                                hint: "admin@lebontaxi.com",
                                type: TextInputType.emailAddress,
                                onSubmitted: (_) => _handleAuth(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  if (!v.contains('@') || !v.contains('.')) return 'E-mail invalide';
                                  return null;
                                }),
                              const SizedBox(height: 18),

                              // Password
                              _input(_passwordCtrl, "Mot de passe", Icons.lock_rounded,
                                hint: _registering ? "6 caractères min." : "••••••••",
                                obscure: _obscure,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscure = !_obscure),
                                  child: Icon(
                                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: const Color(0xFF475569), size: 20,
                                  ),
                                ),
                                onSubmitted: (_) => _handleAuth(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  if (v.length < 6) return 'Minimum 6 caractères';
                                  return null;
                                }),

                              if (!_registering) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () => _snack("Contactez l'administrateur système", false),
                                    child: Text("Mot de passe oublié ?", style: GoogleFonts.inter(
                                      color: const Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w600,
                                    )),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              // Submit
                              _submitBtn(),

                              const SizedBox(height: 28),

                              // Separator
                              Row(children: [
                                Expanded(child: Container(height: 1, decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    const Color(0xFF1E293B).withOpacity(0.8),
                                  ]),
                                ))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text("ou", style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 13)),
                                ),
                                Expanded(child: Container(height: 1, decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    const Color(0xFF1E293B).withOpacity(0.8),
                                    Colors.transparent,
                                  ]),
                                ))),
                              ]),

                              const SizedBox(height: 28),

                              // Google
                              _googleBtn(),

                              const SizedBox(height: 32),

                              // Toggle
                              Center(
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(
                                    _registering ? "Déjà un compte ? " : "Pas de compte ? ",
                                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() { _registering = !_registering; _formKey.currentState?.reset(); }),
                                    child: Text(
                                      _registering ? "Se connecter" : "Créer un compte",
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              Center(child: Text(
                "© ${DateTime.now().year} Le Bon Taxi • Tous droits réservés",
                style: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: 12),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  // ─── INPUT ───

  Widget _input(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return _FocusAwareInput(
      controller: ctrl,
      label: label,
      icon: icon,
      hint: hint,
      type: type,
      obscure: obscure,
      suffix: suffix,
      validator: validator,
      onSubmitted: onSubmitted,
    );
  }

  // ─── BUTTONS ───

  Widget _submitBtn() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        return SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Shimmer sweep
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset((_shimmerCtrl.value * 2 - 0.5) * 500, 0),
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.18),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Button
                  Positioned.fill(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: const Color(0xFF111827),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color(0xFF111827), strokeWidth: 2.5))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(
                                _registering ? "Créer mon compte" : "Se connecter",
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ]),
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

  Widget _googleBtn() {
    return MouseRegion(
      onEnter: (_) => setState(() => _googleHover = true),
      onExit: (_) => setState(() => _googleHover = false),
      child: AnimatedScale(
        scale: _googleHover ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _googleHover
                ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.15), blurRadius: 24, spreadRadius: 2)]
                : [],
          ),
          child: OutlinedButton(
            onPressed: _loading ? null : _googleSignIn,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _googleHover ? const Color(0xFF6366F1).withOpacity(0.5) : const Color(0xFF1E293B),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: const Color(0xFF111827).withValues(alpha: 0.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('images/google-sign.png', width: 20, height: 20,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 22, color: Colors.white54)),
              const SizedBox(width: 12),
              Text("Continuer avec Google", style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Focus-aware Input Widget ───
class _FocusAwareInput extends StatefulWidget {
  const _FocusAwareInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.type,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  @override
  State<_FocusAwareInput> createState() => _FocusAwareInputState();
}

class _FocusAwareInputState extends State<_FocusAwareInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _focused
              ? [BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.08), blurRadius: 16, spreadRadius: 1)]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          keyboardType: widget.type,
          obscureText: widget.obscure,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
            hintText: widget.hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  begin: const Color(0xFF475569),
                  end: _focused ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                ),
                duration: const Duration(milliseconds: 300),
                builder: (_, color, __) => Icon(widget.icon, color: color, size: 20),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52),
            suffixIcon: widget.suffix != null ? Padding(padding: const EdgeInsets.only(right: 16), child: widget.suffix) : null,
            filled: true,
            fillColor: _focused ? const Color(0xFF111827) : const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFBBF24), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            errorStyle: GoogleFonts.inter(fontSize: 12),
          ),
          validator: widget.validator,
        ),
      ),
    );
  }
}
