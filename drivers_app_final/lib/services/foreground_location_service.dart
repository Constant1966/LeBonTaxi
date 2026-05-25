import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service de notification persistante pour le foreground (GPS en arrière-plan)
class ForegroundLocationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 9999;
  static bool _isActive = false;
  static Timer? _durationTimer;
  static int _secondsOnline = 0;

  /// Afficher la notification persistante "En ligne"
  static Future<void> startForegroundNotification() async {
    if (_isActive) return;
    _isActive = true;
    _secondsOnline = 0;

    await _showNotification();

    // Mettre à jour la durée toutes les 60 secondes
    _durationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _secondsOnline += 60;
      _showNotification();
    });
  }

  /// Arrêter la notification persistante
  static Future<void> stopForegroundNotification() async {
    _isActive = false;
    _durationTimer?.cancel();
    _durationTimer = null;
    _secondsOnline = 0;
    await _plugin.cancel(_notificationId);
  }

  /// Afficher / mettre à jour la notification
  static Future<void> _showNotification() async {
    final minutes = _secondsOnline ~/ 60;
    final subtitle = minutes == 0
        ? 'GPS actif — En attente de courses'
        : 'GPS actif — En ligne depuis ${minutes}min';

    const androidDetails = AndroidNotificationDetails(
      'foreground_location',
      'Localisation active',
      channelDescription: 'Indique que le GPS est actif en arrière-plan',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _notificationId,
      '🟢 Le Bon Taxi — En ligne',
      subtitle,
      details,
    );
  }

  static bool get isActive => _isActive;
}
