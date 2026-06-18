import 'package:drivers_app/pages/home_page.dart';
import 'package:drivers_app/pages/messages_page.dart';
import 'package:drivers_app/pages/profile_page.dart';
import 'package:drivers_app/pages/trips_page.dart';
import 'package:drivers_app/utils/responsive_helper.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/widgets/onboarding_guide_overlay.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  TabController? controller;
  int indexSelected = 0;

  // ── Badge messages non lus ────────────────────────────────────
  int _unreadMessageCount = 0;
  RealtimeChannel? _adminMsgChannel;
  RealtimeChannel? _driverMsgChannel;
  String? _myId;
  bool _showGuide = false;

  final List<Widget> _pages = const [
    HomePage(),
    TripsPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  void onBarItemClicked(int i) {
    setState(() {
      indexSelected = i;
      controller!.index = indexSelected;
      // Réinitialiser le badge quand on ouvre l'onglet Messages
      if (i == 2) {
        _unreadMessageCount = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _subscribeToNewMessages();
    _checkShowGuide();
  }

  Future<void> _checkShowGuide() async {
    final completed = await LocalDatabaseService.getAppSetting('has_completed_guide');
    if (completed != 'true') {
      if (mounted) {
        setState(() {
          _showGuide = true;
        });
      }
    }
  }

  @override
  void dispose() {
    controller!.dispose();
    _adminMsgChannel?.unsubscribe();
    _driverMsgChannel?.unsubscribe();
    super.dispose();
  }

  // ── Écouter les nouveaux messages en temps réel ────────────────
  void _subscribeToNewMessages() {
    if (_myId == null) return;

    // Écouter les messages admin destinés à ce chauffeur
    _adminMsgChannel = Supabase.instance.client
        .channel('dashboard_admin_msgs_$_myId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_messages',
      callback: (payload) {
        if (!mounted) return;
        final msg = payload.newRecord;
        final recipientType = msg['recipient_type']?.toString();
        final recipientId = msg['recipient_id']?.toString();

        // Ne compter que les messages destinés à ce chauffeur
        final isForMe = recipientType == 'all_drivers' ||
            recipientType == 'all' ||
            (recipientType == 'single_driver' && recipientId == _myId);

        final recipientName = msg['recipient_name']?.toString() ?? '';

        if (isForMe && !recipientName.startsWith('↩') && indexSelected != 2) {
          setState(() => _unreadMessageCount++);
        }
      },
    ).subscribe();

    // Écouter les messages entre chauffeurs (reçus)
    _driverMsgChannel = Supabase.instance.client
        .channel('dashboard_driver_msgs_$_myId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'driver_messages',
      callback: (payload) {
        if (!mounted) return;
        final msg = payload.newRecord;
        final receiverId = msg['receiver_id']?.toString();

        // Ne compter que les messages reçus (pas envoyés)
        if (receiverId == _myId && indexSelected != 2) {
          setState(() => _unreadMessageCount++);
        }
      },
    ).subscribe();
  }

  // ── Widget badge pour l'icône Messages ────────────────────────
  Widget _buildMessageIcon({required IconData icon}) {
    if (_unreadMessageCount <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text(
        _unreadMessageCount > 9 ? '9+' : '$_unreadMessageCount',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.red,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mainLayout = ResponsiveLayout(
      // ─── MOBILE ─── BottomNavigationBar
      mobileLayout: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          controller: controller,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: BottomNavigationBar(
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    activeIcon: Icon(Icons.home),
                    label: "Accueil",
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.local_taxi_outlined),
                    activeIcon: Icon(Icons.local_taxi),
                    label: "Courses",
                  ),
                  BottomNavigationBarItem(
                    icon: _buildMessageIcon(icon: Icons.message_outlined),
                    activeIcon: _buildMessageIcon(icon: Icons.message),
                    label: "Messages",
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: "Profil",
                  ),
                ],
                currentIndex: indexSelected,
                backgroundColor: Colors.transparent,
                elevation: 0,
                unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                selectedItemColor: AppColors.primary,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                onTap: onBarItemClicked,
              ),
            ),
          ),
        ),
      ),

      // ─── TABLETTE ─── NavigationRail sur le côté
      tabletLayout: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: indexSelected,
              onDestinationSelected: onBarItemClicked,
              extended: MediaQuery.of(context).size.width > 800,
              minExtendedWidth: 200,
              backgroundColor: theme.cardColor,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedIconTheme: IconThemeData(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
              elevation: 4,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_rounded),
                  selectedIcon: Icon(Icons.home),
                  label: Text("Accueil"),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.local_taxi_outlined),
                  selectedIcon: Icon(Icons.local_taxi),
                  label: Text("Courses"),
                ),
                NavigationRailDestination(
                  icon: _buildMessageIcon(icon: Icons.message_outlined),
                  selectedIcon: _buildMessageIcon(icon: Icons.message),
                  label: const Text("Messages"),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text("Profil"),
                ),
              ],
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Image.asset(
                  'assets/images/final_logo.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.local_taxi,
                      size: 48,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ),
            VerticalDivider(
                thickness: 1,
                width: 1,
                color: isDark ? Colors.grey.shade800 : null),
            // Contenu principal
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: controller,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );

    if (_showGuide) {
      return Scaffold(
        body: Stack(
          children: [
            mainLayout,
            OnboardingGuideOverlay(
              onSkipOrFinish: () async {
                await LocalDatabaseService.saveAppSetting('has_completed_guide', 'true');
                if (mounted) {
                  setState(() {
                    _showGuide = false;
                  });
                }
              },
            ),
          ],
        ),
      );
    }

    return mainLayout;
  }
}