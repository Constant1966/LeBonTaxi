import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  // ── Stats (chargement ponctuel + timer 30s) ──────────────────────────────
  int totalDrivers = 0, totalUsers = 0, totalTrips = 0,
      activeDrivers = 0, blockedUsers = 0, tripsToday = 0;
  double totalEarnings = 0.0, earningsToday = 0.0, cancelRate = 0.0;
  List<Map<String, dynamic>> recentTrips = [];
  List<double> weeklyTrips = List.filled(7, 0);
  List<double> weeklyEarnings = List.filled(7, 0);
  bool isLoading = true;
  Timer? _refreshTimer;

  // ── Animation ────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _animValue;

  // ── Carte : polling chauffeurs (5s) ───────────────────────────────────
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _mapDrivers = [];
  Timer? _mapPollTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
    _animValue = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    loadDashboardData();
    _loadMapDrivers();
    // Stats toutes les 30s
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30), (_) => loadDashboardData(silent: true));
    // Carte toutes les 5s
    _mapPollTimer = Timer.periodic(
      const Duration(seconds: 5), (_) => _loadMapDrivers());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapPollTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Charger les chauffeurs pour la carte (polling 5s)
  Future<void> _loadMapDrivers() async {
    try {
      final data = await _supabase.from('drivers').select();
      final onlineCount = data.where((d) => d['is_online'] == true || d['is_available'] == true).length;
      final withPosCount = data.where((d) => d['current_latitude'] != null && d['current_longitude'] != null).length;
      print('📡 [Dashboard] ${data.length} chauffeurs chargés | $onlineCount en ligne | $withPosCount avec position GPS');
      if (data.isEmpty) {
        print('⚠️ [Dashboard] 0 chauffeurs ! Vérifiez RLS sur la table drivers. User: ${_supabase.auth.currentUser?.email}');
      }
      if (mounted) {
        setState(() => _mapDrivers = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('❌ [Dashboard] Erreur chargement chauffeurs: $e');
    }
  }

  // ── Chargement des stats ─────────────────────────────────────────────────
  Future<void> loadDashboardData({bool silent = false}) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final driversResp = await _supabase.from('drivers').select();
      totalDrivers  = driversResp.length;
      activeDrivers = driversResp.where((d) => d['block_status'] == 'no').length;

      double earnTotal = 0.0;
      try {
        final earningsResp = await _supabase.from('earnings').select();
        earnTotal = (earningsResp as List).fold(
          0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
      } catch (_) {}
      totalEarnings = earnTotal;

      final usersResp = await _supabase.from('users').select();
      totalUsers   = usersResp.length;
      blockedUsers = usersResp.where((u) => u['block_status'] == 'yes').length;

      final tripsResp = await _supabase.from('trip_requests').select();
      totalTrips = tripsResp.where((t) => t['status'] == 'completed').length;
      final cancelledCount = tripsResp.where((t) => t['status'] == 'cancelled').length;
      cancelRate = tripsResp.isNotEmpty ? (cancelledCount / tripsResp.length) * 100 : 0;

      tripsToday = tripsResp.where((t) {
        final dt = t['created_at']?.toString() ?? '';
        return dt.compareTo(todayStart) >= 0 && t['status'] == 'completed';
      }).length;

      earningsToday = tripsResp
          .where((t) {
            final dt = t['created_at']?.toString() ?? '';
            return dt.compareTo(todayStart) >= 0 && t['status'] == 'completed';
          })
          .fold(0.0, (sum, t) =>
              sum + ((t['fare_amount'] as num?)?.toDouble() ??
                  double.tryParse(t['fare_amount']?.toString() ?? '0') ?? 0));

      weeklyTrips    = List.filled(7, 0);
      weeklyEarnings = List.filled(7, 0);
      for (int i = 0; i < 7; i++) {
        final day      = now.subtract(Duration(days: 6 - i));
        final dayStart = DateTime(day.year, day.month, day.day).toIso8601String();
        final dayEnd   = DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
        final dayTrips = tripsResp.where((t) {
          final dt = t['created_at']?.toString() ?? '';
          return dt.compareTo(dayStart) >= 0 && dt.compareTo(dayEnd) <= 0 && t['status'] == 'completed';
        });
        weeklyTrips[i]    = dayTrips.length.toDouble();
        weeklyEarnings[i] = dayTrips.fold(0.0, (sum, t) =>
            sum + ((t['fare_amount'] as num?)?.toDouble() ??
                double.tryParse(t['fare_amount']?.toString() ?? '0') ?? 0));
      }

      final sorted = tripsResp.where((t) => t['status'] == 'completed').toList()
        ..sort((a, b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
      recentTrips = sorted.take(5).toList();

      if (mounted) {
        setState(() => isLoading = false);
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Interprète is_online / is_available (bool, int, String) ─────────────
  bool _parseOnline(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) {
      final v = val.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes' || v == 'online';
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Dashboard", style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(isDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.home, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text("Accueil", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                const SizedBox(width: 4),
                Text(">", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(width: 4),
                const Text("Dashboard", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 28),

          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator()))
          else ...[
            // Stat cards
            LayoutBuilder(builder: (ctx, constraints) {
              final cardWidth = constraints.maxWidth > 1000
                  ? (constraints.maxWidth - 48) / 4
                  : constraints.maxWidth > 600
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                _circularStatCard(width: cardWidth, label: "Courses", value: totalTrips,
                    maxValue: max(totalTrips, 100), color: AppColors.warning,
                    trend: "Total terminées", trendUp: true, isDark: isDark),
                _circularStatCard(width: cardWidth, label: "Annulations", value: cancelRate.toInt(),
                    maxValue: 100, color: AppColors.cyan,
                    trend: "${cancelRate.toStringAsFixed(1)}%", trendUp: cancelRate < 15, isDark: isDark),
                _circularStatCard(width: cardWidth, label: "Utilisateurs", value: totalUsers,
                    maxValue: max(totalUsers, 100), color: AppColors.danger,
                    trend: "$blockedUsers bloqués", trendUp: true, isDark: isDark),
                _circularStatCard(width: cardWidth, label: "Collection", value: totalEarnings.toInt(),
                    maxValue: max(totalEarnings.toInt(), 10000), color: AppColors.purple,
                    trend: "${earningsToday.toStringAsFixed(0)} HTG aujourd'hui",
                    trendUp: earningsToday > 0, isDark: isDark),
              ]);
            }),
            const SizedBox(height: 28),

            // Bar Chart
            _barChartSection(isDark),
            const SizedBox(height: 28),

            // ── CARTE TEMPS RÉEL ─────────────────────────────────────────
            _mapSection(isDark),
            const SizedBox(height: 28),

            // Bottom row
            LayoutBuilder(builder: (ctx, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _miniStatsSection(isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _recentTripsSection(isDark)),
                ]);
              }
              return Column(children: [
                _miniStatsSection(isDark),
                const SizedBox(height: 16),
                _recentTripsSection(isDark),
              ]);
            }),
          ],
        ]),
      ),
    );
  }

  // ── CARTE : StreamBuilder sur drivers + suivi de course ──────────────────
  String? _trackingDriverId;
  Map<String, dynamic>? _trackingDriverData;
  Map<String, dynamic>? _trackingTripData;

  Widget _mapSection(bool isDark) {
    const center = LatLng(18.53917, -72.335); // Port-au-Prince

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("CARTE DES CHAUFFEURS", style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16,
              color: AppColors.textPrimary(isDark), letterSpacing: 0.5)),
          Row(children: [
            if (_trackingDriverId != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _trackingDriverId = null;
                    _trackingDriverData = null;
                    _trackingTripData = null;
                  }),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text("Arrêter le suivi"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            _legendDot(Colors.green,         "En ligne",   isDark),
            const SizedBox(width: 16),
            _legendDot(Colors.grey,           "Hors ligne", isDark),
            const SizedBox(width: 16),
            _legendDot(Colors.orange.shade400, "En course",  isDark),
          ]),
        ]),
        const SizedBox(height: 16),

        // ── Carte avec polling (pas de StreamBuilder) ──
        Builder(
          builder: (context) {
            final drivers = _mapDrivers;

            int onlineCount  = 0;
            int onTripCount  = 0;

            final List<Marker> markers = [];
            LatLng? trackingCenter;

            for (final d in drivers) {
              final lat = (d['current_latitude']  as num?)?.toDouble()
                       ?? (d['latitude']           as num?)?.toDouble();
              final lng = (d['current_longitude'] as num?)?.toDouble()
                       ?? (d['longitude']          as num?)?.toDouble();

              if (lat == null || lng == null) continue;
              if (lat == 0.0 && lng == 0.0) continue;

              final isOnline  = _parseOnline(d['is_online']) || _parseOnline(d['is_available']);
              final isOnTrip  = d['status']?.toString() == 'on_trip'
                             || d['current_trip_id'] != null;
              final name      = d['name']?.toString() ?? 'Chauffeur';
              final driverId  = d['id']?.toString() ?? '';

              if (isOnline) onlineCount++;
              if (isOnTrip) onTripCount++;

              // If tracking this driver, update data
              if (_trackingDriverId == driverId) {
                _trackingDriverData = d;
                trackingCenter = LatLng(lat, lng);
              }

              final Color markerColor = isOnTrip
                  ? Colors.orange.shade400
                  : isOnline ? Colors.green : Colors.grey;

              final bool isTracked = _trackingDriverId == driverId;

              markers.add(Marker(
                point: LatLng(lat, lng),
                width: isTracked ? 60 : 50,
                height: isTracked ? 70 : 60,
                child: GestureDetector(
                  onTap: () => _startTrackingDriver(d),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: EdgeInsets.all(isTracked ? 6 : 4),
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: markerColor.withOpacity(isTracked ? 0.6 : 0.4), blurRadius: isTracked ? 10 : 6, spreadRadius: isTracked ? 4 : 2)],
                        border: isTracked ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Icon(Icons.local_taxi, color: Colors.white, size: isTracked ? 24 : 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
                      ),
                      child: Text(
                        name.split(' ').first,
                        style: TextStyle(fontSize: isTracked ? 10 : 9, fontWeight: FontWeight.bold,
                            color: isTracked ? AppColors.primary : (isDark ? Colors.white : Colors.black87)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ));
            }

            return Column(children: [
              if (drivers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    _summaryChip(Icons.circle, "$onlineCount  en ligne",  Colors.green, isDark),
                    const SizedBox(width: 8),
                    _summaryChip(Icons.directions_car, "$onTripCount  en course", Colors.orange.shade400, isDark),
                    const SizedBox(width: 8),
                    _summaryChip(Icons.people, "${drivers.length}  total", AppColors.info, isDark),
                    const Spacer(),
                    Icon(Icons.wifi, size: 14, color: Colors.green.shade400),
                    const SizedBox(width: 4),
                    Text("Polling 5s", style: TextStyle(fontSize: 11, color: Colors.green.shade400, fontWeight: FontWeight.w500)),
                  ]),
                ),

              // Tracking info panel
              if (_trackingDriverId != null && _trackingDriverData != null)
                _buildTrackingPanel(isDark),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: _trackingDriverId != null ? 500 : 400,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: trackingCenter ?? center,
                      initialZoom: _trackingDriverId != null ? 14.0 : 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.lebontaxi.admin',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),

              if (markers.isEmpty && drivers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.location_off, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      "Aucun chauffeur avec une position GPS valide.\n"
                      "Vérifiez que les colonnes current_latitude / current_longitude\n"
                      "sont bien mises à jour par l'app chauffeur.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );
  }

  // ── Start tracking a driver ──────────────────────────────────────────────
  void _startTrackingDriver(Map<String, dynamic> driver) async {
    final driverId = driver['id']?.toString() ?? '';
    setState(() {
      _trackingDriverId = driverId;
      _trackingDriverData = driver;
      _trackingTripData = null;
    });

    // Load active trip for this driver
    try {
      final trips = await _supabase.from('trip_requests')
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', ['accepted', 'arrived', 'ontrip'])
          .order('created_at', ascending: false)
          .limit(1);
      if (trips.isNotEmpty && mounted) {
        setState(() => _trackingTripData = trips.first);
      }
    } catch (_) {}
  }

  // ── Tracking panel ─────────────────────────────────────────────────────
  Widget _buildTrackingPanel(bool isDark) {
    final d = _trackingDriverData!;
    final trip = _trackingTripData;
    final isOnline = _parseOnline(d['is_online']) || _parseOnline(d['is_available']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardHover : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Driver photo
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(d['photo']?.toString() ?? '', width: 60, height: 60, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 60, height: 60,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.person, color: AppColors.primary, size: 30)),
          ),
        ),
        const SizedBox(width: 16),
        // Driver info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(d['name']?.toString() ?? 'Chauffeur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary(isDark))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: isOnline ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(isOnline ? "En ligne" : "Hors ligne", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? AppColors.success : Colors.grey)),
            ),
          ]),
          const SizedBox(height: 4),
          Text("${d['car_model'] ?? ''} • ${d['car_number'] ?? ''}", style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark))),
          Text(d['phone']?.toString() ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark))),
        ])),
        // Trip info
        if (trip != null) ...[
          Container(width: 1, height: 60, color: AppColors.border(isDark)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("Course en cours", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.circle, size: 8, color: Colors.green.shade400), const SizedBox(width: 6),
              Expanded(child: Text(trip['pickup_address']?.toString() ?? '—', style: TextStyle(fontSize: 11, color: AppColors.textPrimary(isDark)), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.circle, size: 8, color: Colors.red.shade400), const SizedBox(width: 6),
              Expanded(child: Text(trip['dropoff_address']?.toString() ?? '—', style: TextStyle(fontSize: 11, color: AppColors.textPrimary(isDark)), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text("${trip['fare_amount'] ?? '—'} HTG • ${trip['user_name'] ?? 'Client'}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ])),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text("Aucune course active", style: TextStyle(fontSize: 12, color: AppColors.textTertiary(isDark), fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Bar Chart ─────────────────────────────────────────────────────────────
  Widget _barChartSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("BAR CHART", style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16,
              color: AppColors.textPrimary(isDark), letterSpacing: 0.5)),
          Row(children: [
            _legendDot(Colors.orange, "Courses", isDark),
            const SizedBox(width: 16),
            _legendDot(AppColors.info, "Revenus (÷100)", isDark),
          ]),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          child: BarChart(BarChartData(
            barGroups: List.generate(7, (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: weeklyTrips[i], color: Colors.orange.shade400, width: 14,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3))),
                BarChartRodData(toY: weeklyEarnings[i] / 100, color: AppColors.info, width: 14,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3))),
              ],
              barsSpace: 4,
            )),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v, m) {
                  final day = DateTime.now().subtract(Duration(days: 6 - v.toInt()));
                  return Padding(padding: const EdgeInsets.only(top: 10),
                    child: Text(DateFormat('E', 'fr_FR').format(day).substring(0, 3).toUpperCase(),
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark), fontWeight: FontWeight.w500)));
                })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35,
                getTitlesWidget: (v, m) => Text(v.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary(isDark))))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: true,
              getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border(isDark).withValues(alpha: 0.5), strokeWidth: 1),
              getDrawingVerticalLine:   (v) => FlLine(color: AppColors.border(isDark).withValues(alpha: 0.3), strokeWidth: 1)),
            borderData: FlBorderData(show: true, border: Border(
              left:   BorderSide(color: AppColors.border(isDark)),
              bottom: BorderSide(color: AppColors.border(isDark)))),
          )),
        ),
      ]),
    );
  }

  // ── Mini stats ────────────────────────────────────────────────────────────
  Widget _miniStatsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Statistiques rapides", style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary(isDark))),
        const SizedBox(height: 20),
        _miniStatRow(Icons.today,           "Courses aujourd'hui", tripsToday.toString(),               AppColors.primary,  isDark),
        const SizedBox(height: 14),
        _miniStatRow(Icons.trending_up,     "CA aujourd'hui",      "${earningsToday.toStringAsFixed(0)} HTG", AppColors.success, isDark),
        const SizedBox(height: 14),
        _miniStatRow(Icons.local_taxi,      "Chauffeurs actifs",   "$activeDrivers / $totalDrivers",    AppColors.info,     isDark),
        const SizedBox(height: 14),
        _miniStatRow(Icons.block,           "Bloqués",             "${totalDrivers - activeDrivers} chauffeurs", AppColors.danger, isDark),
        const SizedBox(height: 14),
        _miniStatRow(Icons.cancel_outlined, "Taux annulation",     "${cancelRate.toStringAsFixed(1)}%", AppColors.warning,  isDark),
      ]),
    );
  }

  Widget _miniStatRow(IconData icon, String label, String value, Color color, bool isDark) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color)),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)))),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark))),
    ]);
  }

  // ── Courses récentes ──────────────────────────────────────────────────────
  Widget _recentTripsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Dernières courses", style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary(isDark))),
        const SizedBox(height: 16),
        if (recentTrips.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Text("Aucune course récente",
                style: TextStyle(color: AppColors.textSecondary(isDark)))))
        else
          ...recentTrips.map((trip) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardHover : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border(isDark).withValues(alpha: 0.5))),
            child: Row(children: [
              CircleAvatar(radius: 18,
                backgroundColor: AppColors.taxiYellow.withValues(alpha: 0.15),
                child: const Icon(Icons.local_taxi, size: 16, color: AppColors.taxiYellow)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${trip['user_name'] ?? 'Client'} → ${trip['driver_name'] ?? 'Chauffeur'}",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                        color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 2),
                Text(trip['created_at']?.toString().substring(0, 16) ?? '',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary(isDark))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text("${trip['fare_amount'] ?? '0'} HTG",
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color: AppColors.success, fontSize: 12))),
            ]),
          )),
      ]),
    );
  }

  // ── Carte stat circulaire ─────────────────────────────────────────────────
  Widget _circularStatCard({required double width, required String label,
      required int value, required int maxValue, required Color color,
      required String trend, required bool trendUp, required bool isDark}) {
    final progress = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return SizedBox(width: width, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(animation: _animValue, builder: (context, _) {
          return SizedBox(width: 90, height: 90, child: CustomPaint(
            painter: _CircleProgressPainter(
              progress: progress * _animValue.value, color: color,
              bgColor: AppColors.border(isDark), strokeWidth: 4),
            child: Center(child: Text(
              value > 999 ? "${(value / 1000).toStringAsFixed(1)}k" : value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark)))),
          ));
        }),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(isDark))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(trendUp ? Icons.trending_up : Icons.trending_down,
              size: 14, color: trendUp ? AppColors.success : AppColors.danger),
          const SizedBox(width: 4),
          Text(trend, style: TextStyle(fontSize: 12,
              color: trendUp ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w500)),
        ]),
      ]),
    ));
  }

  Widget _legendDot(Color color, String label, bool isDark) {
    return Row(children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark))),
    ]);
  }
}

// ── Peintre cercle de progression ─────────────────────────────────────────
class _CircleProgressPainter extends CustomPainter {
  final double progress, strokeWidth;
  final Color color, bgColor;
  const _CircleProgressPainter({required this.progress, required this.color,
      required this.bgColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawCircle(center, radius,
        Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false,
      Paint()..color = color..style = PaintingStyle.stroke
             ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) => old.progress != progress;
}