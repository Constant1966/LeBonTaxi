import '../dashboard/dashboard.dart';
import '../pages/drivers_page.dart';
import '../pages/trips_page.dart';
import '../pages/users_page.dart';
import '../pages/login_page.dart';
import '../pages/app_settings_page.dart';
import '../pages/subscription_plans_page.dart';
import '../pages/live_trips_page.dart';
import '../pages/communication_page.dart';
import '../pages/pricing_discounts_page.dart';
import '../pages/reviews_page.dart';
import '../pages/admin_logs_page.dart';
import '../providers/theme_provider.dart';
import '../constants/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SideNavigationDrawer extends StatefulWidget {
  const SideNavigationDrawer({super.key});

  @override
  State<SideNavigationDrawer> createState() => _SideNavigationDrawerState();
}

class _SideNavigationDrawerState extends State<SideNavigationDrawer> {
  Widget chosenScreen = const Dashboard();
  String _selectedRoute = "dashboard";

  // ✅ Notifications
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  RealtimeChannel? _notifChannel;

  // ✅ Admin info
  String _adminEmail = "";
  String _adminName = "";
  String? _adminPhoto;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAdminInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _adminEmail = user.email ?? "";
        _adminName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? "Admin";
        _adminPhoto = user.userMetadata?['picture'] ?? user.userMetadata?['avatar_url'];
      });
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await Supabase.instance.client
          .from('admin_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _unreadCount = _notifications.length;
        });
      }
    } catch (e) {
      print("⚠️ Notifications non chargées: $e");
    }
  }

  void _subscribeToNotifications() {
    _notifChannel = Supabase.instance.client
        .channel('admin_notif_bell')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_messages',
      callback: (payload) {
        if (!mounted) return;
        setState(() {
          _notifications.insert(0, payload.newRecord);
          _unreadCount++;
        });
      },
    ).subscribe();
  }

  void sendAdminTo(selectedPage) {
    switch (selectedPage.route) {
      case DriversPage.id:
        setState(() {
          chosenScreen = const DriversPage();
        });
        break;
      case UsersPage.id:
        setState(() {
          chosenScreen = const UsersPage();
        });
        break;
      case TripsPage.id:
        setState(() {
          chosenScreen = const TripsPage();
        });
        break;
      case AppSettingsPage.id:
        setState(() {
          chosenScreen = const AppSettingsPage();
        });
        break;
      case SubscriptionPlansPage.id:
        setState(() {
          chosenScreen = const SubscriptionPlansPage();
        });
        break;
      case LiveTripsPage.id:
        setState(() {
          chosenScreen = const LiveTripsPage();
        });
        break;
      case CommunicationPage.id:
        setState(() {
          chosenScreen = const CommunicationPage();
        });
        break;
      case PricingDiscountsPage.id:
        setState(() {
          chosenScreen = const PricingDiscountsPage();
        });
        break;
      case ReviewsPage.id:
        setState(() {
          chosenScreen = const ReviewsPage();
        });
        break;
      case AdminLogsPage.id:
        setState(() {
          chosenScreen = const AdminLogsPage();
        });
        break;
      case "dashboard":
        setState(() {
          chosenScreen = const Dashboard();
        });
        break;
    }
    setState(() {
      _selectedRoute = selectedPage.route;
    });
  }

  // ✅ Formater la date relative
  String _timeAgo(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return "À l'instant";
      if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
      if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
      if (diff.inDays < 7) return "Il y a ${diff.inDays}j";
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "";
    }
  }

  // ✅ Icône selon le type de notification
  IconData _notifIcon(String? type) {
    switch (type) {
      case 'maintenance': return Icons.build_circle;
      case 'promotion': return Icons.local_offer;
      case 'alert': return Icons.warning_amber_rounded;
      case 'security': return Icons.shield;
      case 'pricing': return Icons.attach_money;
      default: return Icons.campaign;
    }
  }

  Color _notifColor(String? type) {
    switch (type) {
      case 'maintenance': return Colors.orange;
      case 'promotion': return Colors.green;
      case 'alert': return Colors.red;
      case 'security': return Colors.blue;
      case 'pricing': return Colors.purple;
      default: return AppColors.primary;
    }
  }

  // ✅ Afficher le panneau de notifications
  void _showNotificationsPanel(BuildContext context, bool isDark) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Fond semi-transparent pour fermer
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(),
              child: Container(color: Colors.black26),
            ),
          ),
          // Panel
          Positioned(
            top: 65,
            right: 80,
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(16),
              color: AppColors.card(isDark),
              child: Container(
                width: 380,
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border(isDark))),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Text("Notifications", style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary(isDark),
                          )),
                          const Spacer(),
                          if (_unreadCount > 0)
                            TextButton(
                              onPressed: () {
                                setState(() => _unreadCount = 0);
                                entry.remove();
                              },
                              child: const Text("Tout lire", style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    // Liste
                    if (_notifications.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: AppColors.textTertiary(isDark)),
                            const SizedBox(height: 12),
                            Text("Aucune notification", style: TextStyle(color: AppColors.textTertiary(isDark))),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length > 10 ? 10 : _notifications.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(isDark)),
                          itemBuilder: (_, i) {
                            final n = _notifications[i];
                            final type = n['type']?.toString();
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: _notifColor(type).withValues(alpha: 0.15),
                                child: Icon(_notifIcon(type), size: 18, color: _notifColor(type)),
                              ),
                              title: Text(
                                n['title']?.toString() ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                n['message']?.toString() ?? '',
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _timeAgo(n['created_at']?.toString()),
                                style: TextStyle(fontSize: 10, color: AppColors.textTertiary(isDark)),
                              ),
                              dense: true,
                              onTap: () {
                                entry.remove();
                                // Naviguer vers Communication
                                setState(() {
                                  _selectedRoute = CommunicationPage.id;
                                  chosenScreen = const CommunicationPage();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.border(isDark))),
                      ),
                      child: TextButton(
                        onPressed: () {
                          entry.remove();
                          setState(() {
                            _selectedRoute = CommunicationPage.id;
                            chosenScreen = const CommunicationPage();
                          });
                        },
                        child: const Text("Voir tout →", style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
    setState(() => _unreadCount = 0);
  }

  // ✅ Menu profil admin
  void _showAdminMenu(BuildContext context, bool isDark) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx - 120, 65, 20, 0),
      color: AppColors.card(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _adminPhoto != null ? NetworkImage(_adminPhoto!) : null,
                    child: _adminPhoto == null ? const Icon(Icons.person, color: AppColors.primary, size: 22) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_adminName, style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary(isDark),
                        )),
                        Text(_adminEmail, style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary(isDark),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("● En ligne", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 18, color: AppColors.textSecondary(isDark)),
              const SizedBox(width: 10),
              Text("Paramètres", style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logs',
          child: Row(
            children: [
              Icon(Icons.history, size: 18, color: AppColors.textSecondary(isDark)),
              const SizedBox(width: 10),
              Text("Logs admin", style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: AppColors.danger),
              const SizedBox(width: 10),
              Text("Déconnexion", style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'logout') {
        _handleLogout(isDark);
      } else if (value == 'settings') {
        setState(() {
          _selectedRoute = AppSettingsPage.id;
          chosenScreen = const AppSettingsPage();
        });
      } else if (value == 'logs') {
        setState(() {
          _selectedRoute = AdminLogsPage.id;
          chosenScreen = const AdminLogsPage();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final appBar = Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        border: Border(bottom: BorderSide(color: AppColors.border(isDark))),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: Icon(Icons.menu, color: AppColors.textPrimary(isDark)),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Image.asset(
              'images/lebontaxi.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_taxi, color: AppColors.taxiYellow),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Le Bon Taxi",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(isDark),
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "Admin",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // ✅ Search bar (fonctionnelle — ouvre le command palette)
          if (MediaQuery.of(context).size.width > 900)
            InkWell(
              onTap: () => _showSearchPalette(context, isDark),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 180,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardHover : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: AppColors.textTertiary(isDark)),
                    const SizedBox(width: 8),
                    Text("Rechercher...", style: TextStyle(color: AppColors.textTertiary(isDark), fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("⌘K", style: TextStyle(fontSize: 10, color: AppColors.textTertiary(isDark), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.search, color: AppColors.textSecondary(isDark)),
              onPressed: () => _showSearchPalette(context, isDark),
              tooltip: "Recherche rapide (⌘K)",
            ),
          const SizedBox(width: 16),
          // Dark mode toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark
                  ? AppColors.taxiYellow
                  : AppColors.textSecondary(isDark),
              size: 20,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: isDark ? "Mode clair" : "Mode sombre",
          ),
          // ✅ Notifications (cloche fonctionnelle)
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _unreadCount > 0 ? Icons.notifications_active : Icons.notifications_outlined,
                  color: _unreadCount > 0 ? AppColors.primary : AppColors.textSecondary(isDark),
                  size: 22,
                ),
                onPressed: () => _showNotificationsPanel(context, isDark),
                tooltip: "Notifications${_unreadCount > 0 ? ' ($_unreadCount)' : ''}",
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadCount > 9 ? "9+" : "$_unreadCount",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // ✅ Admin avatar (fonctionnel avec menu)
          Builder(
            builder: (ctx) => InkWell(
              onTap: () => _showAdminMenu(ctx, isDark),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _adminPhoto != null ? NetworkImage(_adminPhoto!) : null,
                    child: _adminPhoto == null
                        ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                        : null,
                  ),
                  if (MediaQuery.of(context).size.width > 1050) ...[
                    const SizedBox(width: 8),
                    Text(
                      _adminName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 18, color: AppColors.textTertiary(isDark)),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final mainContent = Column(
      children: [
        appBar,
        Expanded(child: chosenScreen),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      drawer: isDesktop ? null : Drawer(child: _buildCustomSidebar(isDark)),
      body: isDesktop
          ? Row(
              children: [
                _buildCustomSidebar(isDark),
                Expanded(child: mainContent),
              ],
            )
          : Builder(
              builder: (ctx) => mainContent,
            ),
    );
  }

  Widget _buildCustomSidebar(bool isDark) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        border: Border(
          right: BorderSide(color: AppColors.border(isDark)),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildMenuItem(
                  title: "Tableau de bord",
                  route: "dashboard",
                  icon: Icons.dashboard_outlined,
                  isDark: isDark,
                  page: const Dashboard(),
                ),
                _buildMenuItem(
                  title: "Courses en direct",
                  route: LiveTripsPage.id,
                  icon: Icons.gps_fixed,
                  isDark: isDark,
                  page: const LiveTripsPage(),
                ),
                _buildMenuItem(
                  title: "Chauffeurs",
                  route: DriversPage.id,
                  icon: CupertinoIcons.car_detailed,
                  isDark: isDark,
                  page: const DriversPage(),
                ),
                _buildMenuItem(
                  title: "Utilisateurs",
                  route: UsersPage.id,
                  icon: CupertinoIcons.person_2_fill,
                  isDark: isDark,
                  page: const UsersPage(),
                ),
                _buildMenuItem(
                  title: "Historique trajets",
                  route: TripsPage.id,
                  icon: CupertinoIcons.location_fill,
                  isDark: isDark,
                  page: const TripsPage(),
                ),
                _buildMenuItem(
                  title: "Tarifs & Rabais",
                  route: PricingDiscountsPage.id,
                  icon: Icons.attach_money,
                  isDark: isDark,
                  page: const PricingDiscountsPage(),
                ),
                _buildMenuItem(
                  title: "Communication",
                  route: CommunicationPage.id,
                  icon: Icons.message_outlined,
                  isDark: isDark,
                  page: const CommunicationPage(),
                ),
                _buildMenuItem(
                  title: "Commentaires",
                  route: ReviewsPage.id,
                  icon: Icons.reviews_outlined,
                  isDark: isDark,
                  page: const ReviewsPage(),
                ),
                _buildMenuItem(
                  title: "Abonnements",
                  route: SubscriptionPlansPage.id,
                  icon: Icons.card_membership,
                  isDark: isDark,
                  page: const SubscriptionPlansPage(),
                ),
                _buildMenuItem(
                  title: "Paramètres",
                  route: AppSettingsPage.id,
                  icon: Icons.settings,
                  isDark: isDark,
                  page: const AppSettingsPage(),
                ),
                _buildMenuItem(
                  title: "Logs admin",
                  route: AdminLogsPage.id,
                  icon: Icons.history,
                  isDark: isDark,
                  page: const AdminLogsPage(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : Colors.grey.shade100,
              border: Border(top: BorderSide(color: AppColors.border(isDark))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  color: AppColors.textSecondary(isDark),
                  onPressed: () => _showAboutDialog(isDark),
                  tooltip: "Aide",
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  color: AppColors.textSecondary(isDark),
                  tooltip: "Déconnexion",
                  onPressed: () => _handleLogout(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String route,
    required IconData icon,
    required bool isDark,
    required Widget page,
  }) {
    final isSelected = _selectedRoute == route;
    final activeBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFE0E7FF);
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF4338CA);
    final idleColor = AppColors.textSecondary(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          icon,
          size: 20, // Plus petites icônes demandées
          color: isSelected ? activeColor : idleColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? activeColor : idleColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedRoute = route;
            chosenScreen = page;
          });
          // Close drawer on mobile
          if (MediaQuery.of(context).size.width < 800) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ✅ Command Palette — Recherche rapide de pages
  void _showSearchPalette(BuildContext context, bool isDark) {
    final searchCtrl = TextEditingController();
    final pages = [
      {'icon': Icons.dashboard_outlined, 'title': 'Tableau de bord', 'subtitle': 'Vue d\'ensemble', 'page': const Dashboard(), 'route': 'dashboard'},
      {'icon': Icons.gps_fixed, 'title': 'Courses en direct', 'subtitle': 'Suivi temps réel', 'page': const LiveTripsPage(), 'route': LiveTripsPage.id},
      {'icon': CupertinoIcons.car_detailed, 'title': 'Chauffeurs', 'subtitle': 'Gestion des chauffeurs', 'page': const DriversPage(), 'route': DriversPage.id},
      {'icon': CupertinoIcons.person_2_fill, 'title': 'Utilisateurs', 'subtitle': 'Gestion des clients', 'page': const UsersPage(), 'route': UsersPage.id},
      {'icon': CupertinoIcons.location_fill, 'title': 'Historique trajets', 'subtitle': 'Toutes les courses', 'page': const TripsPage(), 'route': TripsPage.id},
      {'icon': Icons.attach_money, 'title': 'Tarifs & Rabais', 'subtitle': 'Tarification et promotions', 'page': const PricingDiscountsPage(), 'route': PricingDiscountsPage.id},
      {'icon': Icons.message_outlined, 'title': 'Communication', 'subtitle': 'Messages et annonces', 'page': const CommunicationPage(), 'route': CommunicationPage.id},
      {'icon': Icons.reviews_outlined, 'title': 'Commentaires', 'subtitle': 'Avis et réponses', 'page': const ReviewsPage(), 'route': ReviewsPage.id},
      {'icon': Icons.card_membership, 'title': 'Abonnements', 'subtitle': 'Plans de souscription', 'page': const SubscriptionPlansPage(), 'route': SubscriptionPlansPage.id},
      {'icon': Icons.settings, 'title': 'Paramètres', 'subtitle': 'Configuration des prix', 'page': const AppSettingsPage(), 'route': AppSettingsPage.id},
      {'icon': Icons.history, 'title': 'Logs admin', 'subtitle': 'Historique des actions', 'page': const AdminLogsPage(), 'route': AdminLogsPage.id},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final query = searchCtrl.text.toLowerCase();
        final filtered = query.isEmpty ? pages : pages.where((p) =>
          (p['title'] as String).toLowerCase().contains(query) ||
          (p['subtitle'] as String).toLowerCase().contains(query)
        ).toList();

        return Dialog(
          backgroundColor: AppColors.card(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border(isDark))),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setDlg(() {}),
                    style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Rechercher une page...",
                      hintStyle: TextStyle(color: AppColors.textTertiary(isDark)),
                      prefixIcon: Icon(Icons.search, color: AppColors.textTertiary(isDark)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                // Results
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text("Aucun résultat", style: TextStyle(color: AppColors.textTertiary(isDark))),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: Icon(p['icon'] as IconData, size: 20, color: AppColors.primary),
                          title: Text(p['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(isDark))),
                          subtitle: Text(p['subtitle'] as String, style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark))),
                          dense: true,
                          hoverColor: AppColors.primary.withValues(alpha: 0.08),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedRoute = p['route'] as String;
                              chosenScreen = p['page'] as Widget;
                            });
                          },
                        );
                      },
                    ),
                  ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border(isDark))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("↑↓ naviguer", style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark))),
                      const SizedBox(width: 16),
                      Text("↵ ouvrir", style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark))),
                      const SizedBox(width: 16),
                      Text("esc fermer", style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _handleLogout(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.card(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Déconnexion',
            style: TextStyle(color: AppColors.textPrimary(isDark)),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(color: AppColors.textSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: TextStyle(color: AppColors.textSecondary(isDark)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  void _showAboutDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Le Bon Taxi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(isDark))),
            Text("Admin Panel v1.0.0", style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark))),
          ]),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          _aboutRow(Icons.build, "Version", "1.0.0", isDark),
          _aboutRow(Icons.flutter_dash, "Framework", "Flutter Web", isDark),
          _aboutRow(Icons.storage, "Backend", "Supabase", isDark),
          _aboutRow(Icons.sync, "Sync", "WebSocket Realtime", isDark),
          const Divider(),
          _aboutRow(Icons.email, "Support", "support@lebontaxi.com", isDark),
          _aboutRow(Icons.phone, "Téléphone", "+509 XXXX-XXXX", isDark),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "© ${DateTime.now().year} Le Bon Taxi — Tous droits réservés",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark)),
            ),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textTertiary(isDark)),
      const SizedBox(width: 10),
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark), fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(isDark)))),
    ]),
  );
}

