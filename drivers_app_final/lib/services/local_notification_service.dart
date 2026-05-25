import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service de notifications locales (système)
/// Affiche des notifications dans la barre de notifications Android/iOS
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Callback quand l'utilisateur tape sur une notification
  static Function(String?)? onNotificationTap;

  /// Initialiser le plugin de notifications locales
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Créer les canaux Android
    await _createNotificationChannels();

    _isInitialized = true;
    print('✅ LocalNotificationService initialisé');
  }

  /// Créer les canaux de notification Android
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Canal pour les courses
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'trip_requests',
        'Demandes de Course',
        description: 'Notifications pour les nouvelles demandes de course',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // Canal pour les paiements
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'payments',
        'Paiements',
        description: 'Notifications de confirmation de paiement',
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Canal pour les urgences
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'emergencies',
        'Urgences',
        description: 'Notifications d\'urgence SOS',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Canal général
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'general',
        'Général',
        description: 'Notifications générales',
        importance: Importance.defaultImportance,
      ),
    );

    // Canal pour le service de localisation en arrière-plan
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'foreground_location',
        'Localisation active',
        description: 'Notification persistante quand le GPS est actif',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    print('✅ Canaux de notification créés');
  }

  /// Callback quand l'utilisateur tape sur une notification
  static void _onNotificationResponse(NotificationResponse response) {
    print('🔔 Notification tapée: ${response.payload}');
    onNotificationTap?.call(response.payload);
  }

  /// Afficher une notification de nouvelle course
  static Future<void> showTripNotification({
    required String tripId,
    required String pickupAddress,
    required String userName,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'trip_requests',
      'Demandes de Course',
      channelDescription: 'Notifications pour les nouvelles demandes de course',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      category: AndroidNotificationCategory.transport,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      ticker: 'Nouvelle course disponible',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      tripId.hashCode,
      '🚕 Nouvelle course — $userName',
      '📍 $pickupAddress',
      details,
      payload: 'trip:$tripId',
    );
  }

  /// Afficher une notification de paiement confirmé
  static Future<void> showPaymentNotification({
    required String tripId,
    required String amount,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'payments',
      'Paiements',
      channelDescription: 'Notifications de confirmation de paiement',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.status,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      tripId.hashCode + 1000,
      '✅ Paiement Confirmé',
      '💰 $amount HTG reçu',
      details,
      payload: 'payment:$tripId',
    );
  }

  /// Afficher une notification d'urgence
  static Future<void> showEmergencyNotification({
    required String emergencyId,
    required String userName,
    required String address,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'emergencies',
      'Urgences',
      channelDescription: 'Notifications d\'urgence SOS',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      ticker: 'URGENCE SOS',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      emergencyId.hashCode + 2000,
      '🚨 URGENCE SOS — $userName',
      '📍 $address',
      details,
      payload: 'emergency:$emergencyId',
    );
  }

  /// Afficher une notification d'annulation de course
  static Future<void> showTripCancelledNotification({
    required String tripId,
    required String userName,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'trip_requests',
      'Demandes de Course',
      channelDescription: 'Notifications pour les demandes de course',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      tripId.hashCode + 3000,
      '❌ Course annulée',
      '$userName a annulé la course',
      details,
      payload: 'cancelled:$tripId',
    );
  }

  /// Annuler une notification spécifique
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Annuler toutes les notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Afficher une notification générique (messages admin, annonces, etc.)
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'general',
      'Général',
      channelDescription: 'Notifications générales',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
