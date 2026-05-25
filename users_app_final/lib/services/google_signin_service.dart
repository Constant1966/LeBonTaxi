import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class GoogleSignInService {
  // ✅ Web Client ID depuis Google Cloud Console (client_type: 3)
  static const String _webClientId =
      '718238288889-922fd4c14gea8hv1pn6nqm7obqnrqtl8.apps.googleusercontent.com';

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
  );

  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print("🔐 [GOOGLE] Démarrage Sign-In...");
      print("🔑 [GOOGLE] serverClientId: $_webClientId");

      // Déconnexion préalable pour forcer un nouveau flux
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("⚠️ [GOOGLE] Connexion annulée");
        return {'success': false, 'error': 'Connexion annulée'};
      }

      print("✅ [GOOGLE] User: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        print("❌ [GOOGLE] idToken manquant — vérifier serverClientId dans Google Cloud Console");
        return {
          'success': false,
          'error': 'Impossible d\'obtenir le token. Vérifiez la configuration Google Cloud.',
        };
      }

      print("✅ [GOOGLE] Tokens obtenus");
      print("📤 [SUPABASE] Connexion avec idToken...");

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        print("❌ [SUPABASE] User null après signInWithIdToken");
        return {'success': false, 'error': 'Échec de connexion Supabase'};
      }

      final userId = response.user!.id;
      print("✅ [SUPABASE] Connecté: $userId");

      // ✅ VÉRIFIER SI PROFIL EXISTE (évite duplicate key error)
      final profile = await _supabase
          .from('users')
          .select('profile_completed, name, nin, phone, email')
          .eq('id', userId)
          .maybeSingle();

      final profileCompleted = profile?['profile_completed'] == true;
      print("📋 [PROFILE] Existe: ${profile != null}, Complet: $profileCompleted");

      // ✅ CRÉER PROFIL SEULEMENT SI N'EXISTE PAS
      if (profile == null) {
        print("📝 [PROFILE] Création nouveau profil...");
        await _supabase.from('users').insert({
          'id': userId,
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
          'photo': googleUser.photoUrl ?? '',
          'phone': '',
          'nin': '',
          'block_status': 'no',
          'profile_completed': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        print("✅ [PROFILE] Profil créé");
      } else {
        print("ℹ️ [PROFILE] Profil existe déjà, skip création");
      }

      return {
        'success': true,
        'userId': userId,
        'email': googleUser.email,
        'name': googleUser.displayName,
        'photo': googleUser.photoUrl,
        'profileCompleted': profileCompleted,
      };
    } on PlatformException catch (e) {
      print("❌ [PLATFORM ERROR] code=${e.code}, message=${e.message}");
      final userMessage = _parseGoogleError(e);
      return {'success': false, 'error': userMessage};
    } catch (e) {
      print("❌ [ERROR] Google Sign-In: $e");
      final errorStr = e.toString();
      // Détecter ApiException même si non capturée comme PlatformException
      if (errorStr.contains('ApiException: 7') || errorStr.contains('network_error')) {
        return {
          'success': false,
          'error': 'Erreur de configuration Google Sign-In.\n\n'
              'Vérifiez :\n'
              '• Connexion Internet\n'
              '• OAuth consent screen (Google Cloud Console)\n'
              '• SHA-1 dans Firebase Console',
        };
      }
      return {'success': false, 'error': 'Erreur: ${e.toString()}'};
    }
  }

  /// Parse les erreurs Google Sign-In et retourne un message utilisateur clair
  static String _parseGoogleError(PlatformException e) {
    final code = e.code;
    final message = e.message ?? '';

    // ApiException: 7 = NETWORK_ERROR (souvent config OAuth)
    if (code == 'network_error' || message.contains('ApiException: 7')) {
      return 'Erreur de connexion Google.\n\n'
          'Solutions possibles :\n'
          '• Vérifiez votre connexion Internet\n'
          '• L\'écran de consentement OAuth n\'est pas configuré\n'
          '• Ajoutez votre email comme utilisateur test dans Google Cloud Console';
    }

    // ApiException: 10 = DEVELOPER_ERROR (SHA-1 mismatch)
    if (code == 'sign_in_failed' || message.contains('ApiException: 10')) {
      return 'Erreur de configuration développeur.\n\n'
          'Le certificat SHA-1 ne correspond pas.\n'
          'Vérifiez Firebase Console → Paramètres du projet.';
    }

    // ApiException: 12500 = SIGN_IN_CANCELLED or consent screen issue
    if (message.contains('ApiException: 12500')) {
      return 'Connexion Google impossible.\n\n'
          'L\'écran de consentement OAuth doit être configuré\n'
          'dans Google Cloud Console.';
    }

    // ApiException: 12501 = User cancelled
    if (message.contains('ApiException: 12501')) {
      return 'Connexion annulée';
    }

    return 'Erreur Google Sign-In: $message';
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      print("✅ [GOOGLE] Déconnecté");
    } catch (e) {
      print("❌ [ERROR] Déconnexion: $e");
    }
  }
}