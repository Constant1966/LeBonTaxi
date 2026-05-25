import 'package:drivers_app/pages/home_page.dart';
import 'package:drivers_app/pages/messages_page.dart';
import 'package:drivers_app/pages/profile_page.dart';
import 'package:drivers_app/pages/trips_page.dart';
import 'package:drivers_app/utils/responsive_helper.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  TabController? controller;
  int indexSelected = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TripsPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  final List<NavigationRailDestination> _railDestinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.home_rounded),
      selectedIcon: Icon(Icons.home),
      label: Text("Accueil"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_taxi_outlined),
      selectedIcon: Icon(Icons.local_taxi),
      label: Text("Courses"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.message_outlined),
      selectedIcon: Icon(Icons.message),
      label: Text("Messages"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text("Profil"),
    ),
  ];

  void onBarItemClicked(int i) {
    setState(() {
      indexSelected = i;
      controller!.index = indexSelected;
    });
  }

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveLayout(
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
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    activeIcon: Icon(Icons.home),
                    label: "Accueil",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.local_taxi_outlined),
                    activeIcon: Icon(Icons.local_taxi),
                    label: "Courses",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.message_outlined),
                    activeIcon: Icon(Icons.message),
                    label: "Messages",
                  ),
                  BottomNavigationBarItem(
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
              destinations: _railDestinations,
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
  }
}