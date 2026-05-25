import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/sync_service.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:flutter/material.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/services/pdf_report_service.dart';
import '../global/global_var.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage>
    with AutomaticKeepAliveClientMixin<EarningsPage> {
  double _totalEarnings = 0.0;
  double _todayEarnings = 0.0;
  double _weekEarnings = 0.0;
  double _monthEarnings = 0.0;
  int _todayTrips = 0;
  int _totalTrips = 0;
  int _weekTrips = 0;
  int _monthTrips = 0;
  bool isLoading = true;
  bool _isOfflineData = false;
  List<Map<String, dynamic>> _recentTrips = [];

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadEarnings() async {
    try {
      final isOnline = await SyncService.isOnline();
      Map<String, dynamic> stats;

      if (isOnline) {
        stats = await SupabaseService.getDriverStatistics();
        _isOfflineData = false;
      } else {
        stats = await LocalDatabaseService.getCachedStatistics();
        _isOfflineData = true;
        print('📴 Gains chargés depuis le cache local');
      }

      if (mounted) {
        setState(() {
          _totalEarnings = (stats['total_earnings'] as num?)?.toDouble() ?? 0.0;
          _todayEarnings = (stats['today_earnings'] as num?)?.toDouble() ?? 0.0;
          _weekEarnings = (stats['week_earnings'] as num?)?.toDouble() ?? 0.0;
          _monthEarnings = (stats['month_earnings'] as num?)?.toDouble() ?? 0.0;
          _todayTrips = stats['today_trips'] as int? ?? 0;
          _totalTrips = stats['total_trips'] as int? ?? 0;
          _weekTrips = stats['week_trips'] as int? ?? 0;
          _monthTrips = stats['month_trips'] as int? ?? 0;
          isLoading = false;
        });
      }

      if (isOnline) {
        final recentData = await SupabaseService.getPaymentHistory(limit: 10);
        if (mounted) {
          setState(() {
            _recentTrips = recentData;
          });
        }
      }
    } catch (e) {
      print("❌ Erreur chargement gains: $e");
      try {
        final cachedStats = await LocalDatabaseService.getCachedStatistics();
        if (mounted) {
          setState(() {
            _totalEarnings = (cachedStats['total_earnings'] as num?)?.toDouble() ?? 0.0;
            _todayEarnings = (cachedStats['today_earnings'] as num?)?.toDouble() ?? 0.0;
            _weekEarnings = (cachedStats['week_earnings'] as num?)?.toDouble() ?? 0.0;
            _monthEarnings = (cachedStats['month_earnings'] as num?)?.toDouble() ?? 0.0;
            _todayTrips = cachedStats['today_trips'] as int? ?? 0;
            _totalTrips = cachedStats['total_trips'] as int? ?? 0;
            _weekTrips = cachedStats['week_trips'] as int? ?? 0;
            _monthTrips = cachedStats['month_trips'] as int? ?? 0;
            _isOfflineData = true;
            isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEarnings();
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
          onRefresh: _loadEarnings,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mes Gains",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Suivez vos revenus en temps réel",
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.4,
                    ),
                  ),

                  if (_isOfflineData) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.shade900.withOpacity(0.3)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? Colors.orange.shade700
                                : Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Données hors-ligne — connectez-vous pour synchroniser',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Card principale - Gains totaux
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Gains Totaux",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        isLoading
                            ? const SizedBox(
                                height: 60,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "${_totalEarnings.toStringAsFixed(0)} HTG",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "$_totalTrips courses terminées",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (!isLoading && _recentTrips.isNotEmpty && !_isOfflineData)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Color(0xFF10B981), size: 20),
                        label: const Text(
                          "Exporter le rapport (PDF)",
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                              color: Color(0xFF10B981), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          PdfReportService.generateEarningsReport(
                            driverName: driverName,
                            totalEarnings: _totalEarnings,
                            totalTrips: _totalTrips,
                            recentTrips: _recentTrips,
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Statistiques périodiques
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.88,
                    children: [
                      _buildPeriodCard(
                        title: "Aujourd'hui",
                        amount: _todayEarnings,
                        trips: _todayTrips,
                        icon: Icons.today_rounded,
                        color: const Color(0xFF3B82F6),
                      ),
                      _buildPeriodCard(
                        title: "Cette semaine",
                        amount: _weekEarnings,
                        trips: _weekTrips,
                        icon: Icons.date_range_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                      _buildPeriodCard(
                        title: "Ce mois",
                        amount: _monthEarnings,
                        trips: _monthTrips,
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFFEC4899),
                      ),
                      _buildPerformanceCard(trips: _monthTrips),
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

  Widget _buildPeriodCard({
    required String title,
    required double amount,
    required int trips,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              const Text("HTG",
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text("$trips courses",
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard({required int trips}) {
    String level;
    String emoji;
    Color color;

    if (trips >= 50) {
      level = "Excellent";
      emoji = "🔥";
      color = const Color(0xFF10B981);
    } else if (trips >= 20) {
      level = "Bon";
      emoji = "⭐";
      color = const Color(0xFFF59E0B);
    } else {
      level = "Débutant";
      emoji = "🚀";
      color = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(level,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5)),
              ),
              const SizedBox(height: 6),
              const Text("Performance",
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text("$trips ce mois",
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}