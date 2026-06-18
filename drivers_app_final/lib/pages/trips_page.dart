import 'package:drivers_app/pages/earnings_page.dart';
import 'package:drivers_app/pages/trips_history_page.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage>
    with AutomaticKeepAliveClientMixin<TripsPage> {
  int _totalTripsCompleted = 0;
  int _todayTrips = 0;
  int _weekTrips = 0;
  bool isLoading = true;

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadTripStats() async {
    try {
      final stats = await SupabaseService.getDriverStatistics();
      if (mounted) {
        setState(() {
          _totalTripsCompleted = stats['completed_trips'] as int? ?? 0;
          _todayTrips = stats['today_trips'] as int? ?? 0;
          _weekTrips = stats['week_trips'] as int? ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Erreur chargement stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTripStats();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTripStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Text(
                    "Mes Courses",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Gérez vos trajets",
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Total Trips Card ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_taxi,
                              color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 24),
                        const Text("Courses Totales",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        isLoading
                            ? const CircularProgressIndicator(
                            color: Colors.white)
                            : Text(_totalTripsCompleted.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("Terminées",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // ✅ espacement réduit + uniforme

                  // ── History Button ────────────────────────────────────────
                  _buildNavCard(
                    context: context,
                    icon: Icons.history,
                    iconColor: AppColors.primary,
                    title: "Historique des courses",
                    subtitle: "Voir toutes les courses terminées",
                    theme: theme,
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (c) => const TripsHistoryPage())),
                  ),

                  const SizedBox(height: 12), // ✅ espacement réduit

                  // ── Earnings Button ───────────────────────────────────────
                  _buildNavCard(
                    context: context,
                    icon: Icons.account_balance_wallet,
                    iconColor: const Color(0xFF10B981),
                    title: "Mes Gains",
                    subtitle: "Suivre vos revenus et performances",
                    theme: theme,
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (c) => const EarningsPage())),
                  ),

                  const SizedBox(height: 20), // ✅ espacement avant grid

                  // ── Quick Stats Grid ──────────────────────────────────────
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,   // ✅ réduit légèrement
                    mainAxisSpacing: 12,    // ✅ réduit légèrement
                    childAspectRatio: 1.3,  // ✅ cards un peu moins hautes
                    children: [
                      _buildStatCard(
                        "Aujourd'hui",
                        _todayTrips.toString(),
                        Icons.today,
                        const Color(0xFF10B981),
                        theme,
                        isDark,
                      ),
                      _buildStatCard(
                        "Cette semaine",
                        _weekTrips.toString(),
                        Icons.date_range,
                        const Color(0xFF8B5CF6),
                        theme,
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable nav card ─────────────────────────────────────────────────────

  Widget _buildNavCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // ✅ padding réduit
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodySmall?.color)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: theme.textTheme.bodySmall?.color, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Stat card ─────────────────────────────────────────────────────────────

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ],
      ),
    );
  }
}