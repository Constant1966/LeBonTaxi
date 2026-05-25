import 'package:admin_lebontaxi_web_panel/pages/splash_screen.dart';
import 'package:admin_lebontaxi_web_panel/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: 'https://hshcsrgztdjawywrbvhv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzaGNzcmd6dGRqYXd5d3Jidmh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzA4MjksImV4cCI6MjA4ODIwNjgyOX0.3iCQy7-i7-S8U_DcdVpUUEB703vz3n54yroK-SJMo44',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Le Bon Taxi - Admin Panel',
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}
