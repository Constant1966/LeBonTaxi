import 'package:flutter/material.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/authentication/login_screen_supabase.dart';
import 'package:users_app/pages/home_page.dart';
import 'package:users_app/pages/complete_profile_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Attendre 2 secondes pour l'animation splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final session = SupabaseService.supabase.auth.currentSession;

      if (session == null) {
        // ❌ Pas connecté → Login
        _navigateToLogin();
        return;
      }

      // ✅ Connecté → Vérifier profil
      final userId = session.user.id;
      final userEmail = session.user.email!;

      print("🔍 Vérification profil pour: $userId");

      final profile = await SupabaseService.supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        // CAS 1 : Profil inexistant → Créer + CompleteProfile
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

      // CAS 2 : Compte bloqué → Logout + Login
      if (profile['block_status'] == 'yes') {
        print("🚫 Compte bloqué");
        await SupabaseService.signOut();
        if (!mounted) return;
        _navigateToLogin();
        return;
      }

      // CAS 3 : Profil incomplet → CompleteProfile
      final profileCompleted = profile['profile_completed'] == true;

      if (!profileCompleted) {
        print("⚠️ Profil incomplet, redirection CompleteProfile...");

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

      // CAS 4 : ✅ Profil complet → HomePage
      print("✅ Profil complet, accès HomePage");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      print("❌ Erreur vérification auth: $e");
      if (!mounted) return;
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreenSupabase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Le Bon Taxi
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(
                  'assets/images/final_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.local_taxi,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Le Bon Taxi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Votre service de taxi',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.blue.shade600,
            ),
          ],
        ),
      ),
    );
  }
}