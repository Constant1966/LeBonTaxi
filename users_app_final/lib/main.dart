import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:users_app/appInfo/app_info.dart';
import 'package:users_app/config/supabase_config.dart';
import 'package:users_app/pages/splash_screen.dart';
import 'package:users_app/services/notification_service.dart';
import 'package:users_app/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:users_app/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // ✅ INITIALISER FIREBASE (AVANT Supabase)
  await Firebase.initializeApp();
  print('✅ Firebase initialisé');

  // INITIALISER SUPABASE
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  print('✅ Supabase initialisé');

  // ✅ INITIALISER SQLITE (Cache local — démarrage rapide)
  await LocalDatabaseService.database;
  print('✅ SQLite initialisé');

  // ✅ INITIALISER NOTIFICATIONS
  await NotificationService.initialize();
  print('✅ Notifications initialisées');

  // ✅ INITIALISER PREFERENCES
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? false;

  // ✅ INITIALISER DATE FORMATTING
  await initializeDateFormatting('fr_FR', null);

  runApp(MyApp(isDarkMode: isDarkMode));
}

class MyApp extends StatelessWidget {
  final bool isDarkMode;
  const MyApp({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
         final appInfo = AppInfo();
         appInfo.isDarkMode = isDarkMode;
         return appInfo;
      },
      child: Consumer<AppInfo>(
        builder: (context, appInfo, child) {
          return MaterialApp(
            title: 'Le Bon Taxi',
            themeMode: appInfo.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              scaffoldBackgroundColor: AppColors.background,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue, 
                brightness: Brightness.dark
              ),
              scaffoldBackgroundColor: AppColors.darkBackground,
              useMaterial3: true,
            ),
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        }
      ),
    );
  }
}