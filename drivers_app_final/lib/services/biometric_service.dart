import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service d'authentification biométrique (empreinte digitale / Face ID)
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';

  // ============================================================
  // VÉRIFICATION DES CAPACITÉS
  // ============================================================

  /// Vérifie si l'appareil supporte la biométrie
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      print('❌ Erreur isDeviceSupported: $e');
      return false;
    }
  }

  /// Vérifie si au moins une biométrie est enregistrée
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      print('❌ Erreur canCheckBiometrics: $e');
      return false;
    }
  }

  /// Retourne la liste des biométries disponibles
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      print('❌ Erreur getAvailableBiometrics: $e');
      return [];
    }
  }

  /// Vérifie si la biométrie est utilisable (device supporté + biométrie enregistrée)
  static Future<bool> isBiometricAvailable() async {
    final supported = await isDeviceSupported();
    final canCheck = await canCheckBiometrics();
    return supported && canCheck;
  }

  // ============================================================
  // AUTHENTIFICATION
  // ============================================================

  /// Lance l'authentification biométrique
  static Future<bool> authenticate({String reason = ''}) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('⚠️ Biométrie non disponible');
        return false;
      }

      final localizedReason = reason.isNotEmpty
          ? reason
          : 'Veuillez vous authentifier pour accéder à Le Bon Taxi';

      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi le PIN/pattern en fallback
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        print('✅ Authentification biométrique réussie');
      } else {
        print('❌ Authentification biométrique échouée');
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('❌ Erreur biométrique: ${e.message}');
      return false;
    }
  }

  // ============================================================
  // PRÉFÉRENCES
  // ============================================================

  /// Vérifie si la biométrie est activée dans les préférences
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Active ou désactive la biométrie
  static Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      print('✅ Biométrie ${enabled ? "activée" : "désactivée"}');
      return true;
    } catch (e) {
      print('❌ Erreur setBiometricEnabled: $e');
      return false;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Retourne une description lisible des biométries disponibles
  static Future<String> getBiometricTypeLabel() async {
    final biometrics = await getAvailableBiometrics();

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Empreinte digitale';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Scanner d\'iris';
    } else if (biometrics.isNotEmpty) {
      return 'Biométrie';
    }
    return 'Non disponible';
  }
}
