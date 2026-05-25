import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour récupérer les paramètres de tarification depuis le web panel
/// Les prix sont définis dans la table `app_settings` de Supabase
class AppSettingsService {
  static final _supabase = Supabase.instance.client;

  // Cache en mémoire
  static double _pricePerKm = 150.0;
  static double _baseFare = 0.0;
  static double _pricePerMinute = 0.0;
  static double _commissionRate = 0.0;
  static double _minFare = 100.0;
  static bool _isLoaded = false;

  // ============================================================
  // GETTERS
  // ============================================================

  static double get pricePerKm => _pricePerKm;
  static double get baseFare => _baseFare;
  static double get pricePerMinute => _pricePerMinute;
  static double get commissionRate => _commissionRate;
  static double get minFare => _minFare;
  static bool get isLoaded => _isLoaded;

  // ============================================================
  // CHARGEMENT DEPUIS SUPABASE
  // ============================================================

  /// Charge tous les paramètres depuis la table `app_settings` (row id=1)
  /// Format: colonnes directes (base_fare, per_km_rate, etc.)
  /// Aligné avec le panel admin et l'app client
  static Future<void> loadSettings() async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (response != null) {
        _baseFare = _parseDouble(response['base_fare'], 0.0);
        _pricePerKm = _parseDouble(response['per_km_rate'], 150.0);
        _pricePerMinute = _parseDouble(response['per_minute_fare'], 0.0);
        _commissionRate = _parseDouble(response['commission_percentage'], 0.0);
        _minFare = _parseDouble(response['minimum_fare'], 100.0);
      }

      _isLoaded = true;

      // Sauvegarder en cache local
      await _saveToCache();

      print('✅ Paramètres de tarification chargés depuis Supabase:');
      print('   💰 Prix/km: $_pricePerKm HTG');
      print('   💰 Base: $_baseFare HTG');
      print('   💰 Prix/min: $_pricePerMinute HTG');
      print('   💰 Commission: $_commissionRate%');
      print('   💰 Min fare: $_minFare HTG');
    } catch (e) {
      print('⚠️ Erreur chargement paramètres, utilisation du cache: $e');
      await _loadFromCache();
    }
  }

  // ============================================================
  // CACHE LOCAL (SharedPreferences)
  // ============================================================

  static Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('setting_price_per_km', _pricePerKm);
      await prefs.setDouble('setting_base_fare', _baseFare);
      await prefs.setDouble('setting_price_per_minute', _pricePerMinute);
      await prefs.setDouble('setting_commission_rate', _commissionRate);
      await prefs.setDouble('setting_min_fare', _minFare);
      await prefs.setBool('settings_cached', true);
      print('✅ Paramètres sauvegardés en cache local');
    } catch (e) {
      print('⚠️ Erreur sauvegarde cache paramètres: $e');
    }
  }

  static Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('settings_cached') ?? false;

      if (cached) {
        _pricePerKm = prefs.getDouble('setting_price_per_km') ?? 150.0;
        _baseFare = prefs.getDouble('setting_base_fare') ?? 0.0;
        _pricePerMinute = prefs.getDouble('setting_price_per_minute') ?? 0.0;
        _commissionRate = prefs.getDouble('setting_commission_rate') ?? 0.0;
        _minFare = prefs.getDouble('setting_min_fare') ?? 100.0;
        _isLoaded = true;
        print('✅ Paramètres chargés depuis le cache local');
      } else {
        print('ℹ️ Pas de cache de paramètres, valeurs par défaut utilisées');
        _isLoaded = true;
      }
    } catch (e) {
      print('⚠️ Erreur lecture cache paramètres: $e');
      _isLoaded = true; // Utiliser les valeurs par défaut
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Forcer le rechargement depuis Supabase
  static Future<void> refresh() async {
    _isLoaded = false;
    await loadSettings();
  }
}
