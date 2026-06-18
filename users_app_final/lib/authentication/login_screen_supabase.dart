import 'package:flutter/material.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/pages/home_page.dart';
import 'package:users_app/authentication/signup_screen_supabase.dart';
import 'package:users_app/services/google_signin_service.dart';
import 'package:users_app/services/notification_service.dart';
import 'package:users_app/pages/complete_profile_page.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/local_database_service.dart';

class LoginScreenSupabase extends StatefulWidget {
  const LoginScreenSupabase({super.key});

  @override
  State<LoginScreenSupabase> createState() => _LoginScreenSupabaseState();
}

class _LoginScreenSupabaseState extends State<LoginScreenSupabase>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _logoScaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    ));
    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _logoController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Connexion Supabase Auth
      final response = await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Erreur de connexion');
      }

      final userId = response.user!.id;
      final userEmail = response.user!.email!;

      print("✅ Auth success: $userId");

      // 2. Récupérer le profil complet
      final profile = await SupabaseService.supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        // ✅ CAS 1 : Aucun profil → Créer profil vide et rediriger
        print("⚠️ Profil inexistant, création...");

        await SupabaseService.supabase.from('users').insert({
          'id': userId,
          'email': userEmail,
          'name': '',  // ✅ Chaîne vide au lieu de null
          'phone': '',  // ✅ Chaîne vide au lieu de null
          'nin': '',  // ✅ Chaîne vide au lieu de null
          'block_status': 'no',
          'profile_completed': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfilePage(
              userId: userId,
              email: userEmail,
              skipNameNinPhone: false,
            ),
          ),
        );
        return;
      }

      // 3. Vérifier block_status
      if (profile['block_status'] == 'yes') {
        await SupabaseService.signOut();
        throw Exception('Compte bloqué. Contactez le support.');
      }

      // 4. Vérifier profile_completed
      final profileCompleted = profile['profile_completed'] == true;

      if (!profileCompleted) {
        // ✅ CAS 2 : Profil incomplet → CompleteProfile
        print("⚠️ Profil incomplet, redirection...");

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfilePage(
              userId: userId,
              email: userEmail,
              initialName: profile['name'],
              skipNameNinPhone: false,
            ),
          ),
        );
        return;
      }

      // 5. ✅ Profil complet → HomePage
      print("✅ Profil complet, connexion réussie");

      // ✅ Rafraîchir FCM token après login
      await NotificationService.refreshToken();

      // ✅ Déjà un compte, pas besoin de montrer le guide
      await LocalDatabaseService.saveAppSetting('has_completed_guide', 'true');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email ou mot de passe incorrect'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final result = await GoogleSignInService.signInWithGoogle();

      if (!mounted) return;
      Navigator.pop(context); // Fermer le loading

      if (result['success'] == true) {
        final profileCompleted = result['profileCompleted'] == true;

        if (profileCompleted) {
          // ✅ Déjà un compte, pas besoin de montrer le guide
          await LocalDatabaseService.saveAppSetting('has_completed_guide', 'true');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CompleteProfilePage(
                userId: result['userId'],
                email: result['email'],
                initialName: result['name'],
              ),
            ),
          );
        }
      } else {
        final errorMsg = result['error'] ?? 'Erreur de connexion';
        // ✅ Utiliser un Dialog pour afficher les erreurs détaillées
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Connexion Google échouée',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Text(
              errorMsg,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Sécurité: fermer le loading dialog en cas d'erreur inattendue
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Animated Le Bon Taxi logo
                  SlideTransition(
                    position: _logoSlideAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100,
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/lebontaxi.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade800,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.local_taxi,
                                    size: 70,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Welcome text
                  Text(
                    'Bon retour !',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimaryColor(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour continuer',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.getTextSecondaryColor(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(fontSize: 16, color: AppColors.getTextPrimaryColor(context)),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: AppColors.getTextSecondaryColor(context)),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade600),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email requis';
                            }
                            if (!value.contains('@')) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(fontSize: 16, color: AppColors.getTextPrimaryColor(context)),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            labelStyle: TextStyle(color: AppColors.getTextSecondaryColor(context)),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Mot de passe requis';
                            }
                            if (value.length < 6) {
                              return 'Minimum 6 caractères';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.getBorderColor(context))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "ou",
                          style: TextStyle(
                            color: AppColors.getTextSecondaryColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.getBorderColor(context))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Google sign-in
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: Image.asset(
                        'assets/images/google-sign.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata,
                          size: 32,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      label: Text(
                        "Continuer avec Google",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimaryColor(context),
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                        side: BorderSide(color: AppColors.getBorderColor(context), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Signup link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, animation, __) => const SignupScreenSupabase(),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                          children: [
                            const TextSpan(text: "Pas de compte ? "),
                            TextSpan(
                              text: "S'inscrire",
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}