import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:users_app/services/supabase_service.dart';

/// Service de notifications push avec Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static String? _fcmToken;

  /// Initialiser les notifications
  static Future<void> initialize() async {
    print("🔔 Initialisation Notifications...");

    // 1. Demander permission
    await _requestPermission();

    // 2. Configurer notifications locales
    await _setupLocalNotifications();

    // 3. Obtenir FCM token
    await _getFCMToken();

    // 4. Gérer messages foreground
    _setupForegroundHandler();

    // 5. Gérer messages background
    _setupBackgroundHandler();

    // 6. Gérer clic sur notification
    _setupNotificationClick();

    print("✅ Notifications initialisées");
  }

  /// Demander permission notifications
  static Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permission notifications accordée');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ Permission notifications provisoire');
    } else {
      print('❌ Permission notifications refusée');
    }
  }

  /// Configuration notifications locales — ✅ Son par défaut de l'appareil
  static Future<void> _setupLocalNotifications() async {
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Obtenir FCM token
  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      print("📱 FCM Token: $_fcmToken");

      // Sauvegarder dans Supabase
      if (_fcmToken != null && SupabaseService.userId != null) {
        await SupabaseService.supabase
            .from('users')
            .update({'fcm_token': _fcmToken})
            .eq('id', SupabaseService.userId!);

        print("✅ FCM Token sauvegardé");
      }

      // Écouter les changements de token
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMToken(newToken);
      });
    } catch (e) {
      print("❌ Erreur FCM Token: $e");
    }
  }

  /// Sauvegarder FCM token dans Supabase
  static Future<void> _saveFCMToken(String token) async {
    try {
      if (SupabaseService.userId != null) {
        await SupabaseService.supabase
            .from('users')
            .update({'fcm_token': token})
            .eq('id', SupabaseService.userId!);
      }
    } catch (e) {
      print("❌ Erreur sauvegarde token: $e");
    }
  }

  /// Gérer messages en foreground (app ouverte)
  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Message reçu (foreground): ${message.notification?.title}");

      // Afficher notification locale
      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? 'Le Bon Taxi',
          body: message.notification!.body ?? '',
          payload: message.data.toString(),
        );
      }

      // Traiter les données
      _handleNotificationData(message.data);
    });
  }

  /// Gérer messages en background
  static void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Handler background (fonction top-level)
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print("🔔 Message reçu (background): ${message.notification?.title}");
  }

  /// Gérer clic sur notification
  static void _setupNotificationClick() {
    // Notification reçue quand app était fermée
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print("🔔 App ouverte via notification");
        _handleNotificationData(message.data);
      }
    });

    // Notification reçue quand app était en background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print("🔔 Notification cliquée (background)");
      _handleNotificationData(message.data);
    });
  }

  /// ✅ Afficher notification locale — Son par défaut de l'appareil
  /// Méthode publique accessible depuis d'autres classes
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'le_bon_taxi_channel',
      'Le Bon Taxi',
      channelDescription: 'Notifications courses Le Bon Taxi',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // ✅ Son par défaut de l'appareil (pas de son custom)
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // ✅ Son par défaut iOS (pas de son custom)
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// ✅ Notification "Chauffeur arrivé" — priorité maximale avec vibration longue
  static Future<void> showDriverArrivedNotification({
    required String driverName,
    String? carDetails,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'trip_events_channel',
      'Événements de course',
      channelDescription: 'Notifications importantes sur votre course',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = carDetails != null && carDetails.isNotEmpty
        ? '$driverName est arrivé à votre point de départ ($carDetails)'
        : '$driverName est arrivé à votre point de départ';

    await _localNotifications.show(
      1001,
      '🚗 Votre chauffeur est arrivé !',
      body,
      details,
      payload: '{"type": "driver_arrived"}',
    );
  }

  /// ✅ Notification "Course terminée" — transition vers le paiement
  static Future<void> showTripCompletedNotification({
    required String fareAmount,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'trip_events_channel',
      'Événements de course',
      channelDescription: 'Notifications importantes sur votre course',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
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

    await _localNotifications.show(
      1002,
      '✅ Course terminée',
      'Montant: $fareAmount HTG — Veuillez procéder au paiement',
      details,
      payload: '{"type": "trip_completed"}',
    );
  }

  /// Gérer clic sur notification locale
  static void _onNotificationTap(NotificationResponse response) {
    print("🔔 Notification tapée: ${response.payload}");
  }

  /// Traiter les données de notification
  static void _handleNotificationData(Map<String, dynamic> data) {
    print("📦 Données notification: $data");

    final type = data['type'];

    switch (type) {
      case 'driver_assigned':
        print("🚗 Chauffeur assigné: ${data['driver_name']}");
        break;
      case 'driver_arrived':
        print("📍 Chauffeur arrivé");
        break;
      case 'trip_started':
        print("🚀 Course démarrée");
        break;
      case 'trip_completed':
        print("✅ Course terminée");
        break;
      case 'trip_cancelled':
        print("❌ Course annulée");
        break;
      default:
        print("ℹ️ Type notification inconnu: $type");
    }
  }

  /// Envoyer notification test (pour debug)
  static Future<void> sendTestNotification() async {
    await showLocalNotification(
      title: 'Test Notification',
      body: 'Ceci est un test de notification Le Bon Taxi',
      payload: '{"type": "test"}',
    );
  }

  /// Obtenir le FCM token actuel
  static String? get fcmToken => _fcmToken;

  /// Supprimer FCM token (déconnexion)
  static Future<void> deleteFCMToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      print("✅ FCM Token supprimé");
    } catch (e) {
      print("❌ Erreur suppression token: $e");
    }
  }

  /// Rafraîchir et sauvegarder le FCM token (après login/signup)
  static Future<void> refreshToken() async {
    await _getFCMToken();
  }
}