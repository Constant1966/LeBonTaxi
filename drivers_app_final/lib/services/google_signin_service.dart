import 'package:google_sign_in/google_sign_in.dart';

/// Service Google Sign-In pour l'app chauffeurs
class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // ✅ Utilisation du Web Client ID configuré dans Google Cloud / Supabase
    serverClientId: '718238288889-922fd4c14gea8hv1pn6nqm7obqnrqtl8.apps.googleusercontent.com',
  );

  /// Sign in avec Google
  static Future<Map<String, dynamic>?> signIn() async {
    try {
      print('🔐 Démarrage Google Sign-In...');

      // Déconnexion préalable pour éviter les bugs
      await _googleSignIn.signOut();

      // Connexion Google
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        print('❌ Connexion Google annulée');
        return null;
      }

      print('✅ Compte Google: ${account.email}');

      // Obtenir les tokens
      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null || auth.accessToken == null) {
        print('❌ Tokens Google manquants');
        return null;
      }

      print('✅ Tokens obtenus');

      return {
        'success': true,
        'email': account.email,
        'name': account.displayName ?? '',
        'photo': account.photoUrl,
        'idToken': auth.idToken!,
        'accessToken': auth.accessToken!,
      };
    } catch (e) {
      print('❌ Erreur Google Sign-In: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      print('✅ Google Sign-Out');
    } catch (e) {
      print('❌ Erreur Sign-Out: $e');
    }
  }

  /// Vérifier si déjà connecté
  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Obtenir le compte actuel
  static Future<GoogleSignInAccount?> getCurrentAccount() async {
    return _googleSignIn.currentUser;
  }
}
