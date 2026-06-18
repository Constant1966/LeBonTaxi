import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:drivers_app/authentication/splash_screen.dart';
import 'package:drivers_app/pages/document_status_page.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:drivers_app/services/local_notification_service.dart';
import 'package:drivers_app/services/sync_service.dart';
import 'package:drivers_app/global/global_var.dart';
import 'package:provider/provider.dart';
import 'package:drivers_app/theme/app_theme.dart';
import 'package:drivers_app/theme/theme_provider.dart';

/// ✅ Background message handler Firebase
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Background notification: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ============================================================
    // 1. FIREBASE (Notifications FCM uniquement)
    // ============================================================
    await Firebase.initializeApp();
    print('✅ Firebase initialisé (FCM only)');

    // Background notification handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ============================================================
    // 2. SUPABASE (Backend principal - Auth + DB + Storage)
    // ============================================================
    await Supabase.initialize(
      url: 'https://hshcsrgztdjawywrbvhv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzaGNzcmd6dGRqYXd5d3Jidmh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzA4MjksImV4cCI6MjA4ODIwNjgyOX0.3iCQy7-i7-S8U_DcdVpUUEB703vz3n54yroK-SJMo44', // REMPLACER PAR VOTRE CLÉ ANON
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    print('✅ Supabase initialisé');

    // ============================================================
    // 3. SQLITE (Base locale pour mode hors-ligne)
    // ============================================================
    await LocalDatabaseService.database;
    print('✅ SQLite initialisé');

    // ============================================================
    // 4. PERMISSIONS (Location + Notifications)
    // ============================================================
    await _requestPermissions();

    // ============================================================
    // 5. SYNC (Écouter les changements de connectivité)
    // ============================================================
    SyncService.startListeningConnectivity();
    print('✅ Service de synchronisation démarré');

    // ============================================================
    // 6. NOTIFICATIONS LOCALES
    // ============================================================
    await LocalNotificationService.initialize();
    print('✅ Notifications locales initialisées');

    // Note: PushNotificationSystem.initialize() est appelé
    // dans home_page.dart via _initializeNotifications()

  } catch (e) {
    print('❌ Erreur initialisation: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

/// Demander les permissions nécessaires
Future<void> _requestPermissions() async {
  try {
    // Location permission (nécessaire pour le tracking)
    final locationStatus = await Permission.locationWhenInUse.status;
    if (!locationStatus.isGranted) {
      await Permission.locationWhenInUse.request();
    }

    // Notification permission (nécessaire pour FCM)
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    print('✅ Permissions demandées');
  } catch (e) {
    print('❌ Erreur permissions: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Le Bon Taxi - Chauffeur',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
          routes: {
            '/document-status': (context) => const DocumentStatusPage(),
          },
        );
      },
    );
  }
}