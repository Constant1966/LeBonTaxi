import '../constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveTripsPage extends StatefulWidget {
  static const String id = "\\webPageLiveTrips";
  const LiveTripsPage({super.key});

  @override
  State<LiveTripsPage> createState() => _LiveTripsPageState();
}

class _LiveTripsPageState extends State<LiveTripsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _liveTrips = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadTrips(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrips({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> result;
      if (_filterStatus == 'all') {
        result = await supabase.from('trip_requests').select().order('created_at', ascending: false);
      } else {
        result = await supabase.from('trip_requests').select().eq('status', _filterStatus).order('created_at', ascending: false);
      }
      if (mounted) setState(() { _liveTrips = result; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'new': return const Color(0xFFF59E0B);
      case 'accepted': return const Color(0xFF3B82F6);
      case 'arrived': return const Color(0xFF8B5CF6);
      case 'ontrip': return const Color(0xFF10B981);
      case 'completed': return const Color(0xFF6B7280);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'new': return 'En attente';
      case 'accepted': return 'Acceptée';
      case 'arrived': return 'Arrivé';
      case 'ontrip': return 'En cours';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return s ?? 'Inconnu';
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'new': return Icons.hourglass_empty;
      case 'accepted': return Icons.check_circle;
      case 'arrived': return Icons.location_on;
      case 'ontrip': return Icons.directions_car;
      case 'completed': return Icons.flag;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(_statusIcon(trip['status']), color: _statusColor(trip['status']), size: 20),
          const SizedBox(width: 12),
          Text("Détails de la course", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ]),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row("ID", trip['trip_id']?.toString() ?? 'N/A', isDark),
            _row("Statut", _statusLabel(trip['status']), isDark),
            _row("Date", trip['created_at']?.toString() ?? 'N/A', isDark),
            _row("Montant", "${trip['fare_amount'] ?? '0'} HTG", isDark),
            const Divider(height: 24),
            _row("Client", trip['user_name']?.toString() ?? 'N/A', isDark),
            _row("Tél. client", trip['user_phone']?.toString() ?? 'N/A', isDark),
            _row("Chauffeur", trip['driver_name']?.toString() ?? 'N/A', isDark),
            _row("Tél. chauffeur", trip['driver_phone']?.toString() ?? 'N/A', isDark),
            _row("Voiture", "${trip['car_model'] ?? ''} ${trip['car_color'] ?? ''} ${trip['car_number'] ?? ''}".trim(), isDark),
            const Divider(height: 24),
            _row("Départ", trip['pickup_address']?.toString() ?? 'N/A', isDark),
            _row("Arrivée", trip['dropoff_address']?.toString() ?? 'N/A', isDark),
            _row("Distance", trip['distance']?.toString() ?? 'N/A', isDark),
            _row("Durée", trip['duration']?.toString() ?? 'N/A', isDark),
            const Divider(height: 24),
            _buildTripMap(trip, isDark),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      );
    },
  );
  }

  Widget _buildTripMap(Map<String, dynamic> trip, bool isDark) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: trip['driver_id'] != null 
          ? Supabase.instance.client.from('drivers').select('current_latitude, current_longitude').eq('id', trip['driver_id']).maybeSingle()
          : Future.value(null),
      builder: (context, snapshot) {
        final driverData = snapshot.data;
        final driverLat = (driverData?['current_latitude'] as num?)?.toDouble();
        final driverLng = (driverData?['current_longitude'] as num?)?.toDouble();

        final pLat = (trip['pickup_lat'] as num?)?.toDouble() ?? (trip['pickup_latitude'] as num?)?.toDouble();
        final pLng = (trip['pickup_lng'] as num?)?.toDouble() ?? (trip['pickup_longitude'] as num?)?.toDouble();
        
        final dLat = (trip['dropoff_lat'] as num?)?.toDouble() ?? (trip['dropoff_latitude'] as num?)?.toDouble();
        final dLng = (trip['dropoff_lng'] as num?)?.toDouble() ?? (trip['dropoff_longitude'] as num?)?.toDouble();

        if (pLat == null || pLng == null) {
          return Center(child: Text("Coordonnées GPS indisponibles", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)));
        }

        final center = LatLng(pLat, pLng);
        List<Marker> markers = [];
        
        markers.add(Marker(
          point: center,
          width: 40, height: 40,
          child: const Tooltip(message: "Départ", child: Icon(Icons.location_on, color: Colors.green, size: 30)),
        ));

        if (dLat != null && dLng != null) {
          markers.add(Marker(
            point: LatLng(dLat, dLng),
            width: 40, height: 40,
            child: const Tooltip(message: "Arrivée", child: Icon(Icons.flag, color: Colors.red, size: 30)),
          ));
        }

        if (driverLat != null && driverLng != null) {
          markers.add(Marker(
            point: LatLng(driverLat, driverLng),
            width: 40, height: 40,
            child: const Tooltip(message: "Chauffeur", child: Icon(Icons.local_taxi, color: Color(0xFF6366F1), size: 30)),
          ));
        }

        return Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.lebontaxi.admin',
                ),
                if (dLat != null && dLng != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [center, LatLng(dLat, dLng)],
                        color: Colors.blue,
                        strokeWidth: 3.0,
                        pattern: StrokePattern.dashed(segments: const [10, 10]),
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _row(String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int activeCount = _liveTrips.where((t) => ['new', 'accepted', 'arrived', 'ontrip'].contains(t['status'])).length;
    final filters = [
      {'value': 'all', 'label': 'Toutes', 'color': const Color(0xFF6366F1)},
      {'value': 'new', 'label': 'En attente', 'color': const Color(0xFFF59E0B)},
      {'value': 'accepted', 'label': 'Acceptée', 'color': const Color(0xFF3B82F6)},
      {'value': 'ontrip', 'label': 'En cours', 'color': const Color(0xFF10B981)},
      {'value': 'completed', 'label': 'Terminée', 'color': const Color(0xFF6B7280)},
      {'value': 'cancelled', 'label': 'Annulée', 'color': const Color(0xFFEF4444)},
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text("Courses en direct", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text("$activeCount actives", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 4),
              Text("Rafraîchissement auto toutes les 5s", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ]),
            IconButton(onPressed: () => _loadTrips(), icon: const Icon(Icons.refresh), tooltip: "Rafraîchir"),
          ]),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: filters.map((f) {
              final isActive = _filterStatus == f['value'];
              final c = f['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isActive, selectedColor: c, checkmarkColor: Colors.white,
                  label: Text(f['label'] as String),
                  labelStyle: TextStyle(color: isActive ? Colors.white : null, fontWeight: FontWeight.w500, fontSize: 12),
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  side: BorderSide(color: isActive ? c : (isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                  onSelected: (_) { setState(() => _filterStatus = f['value'] as String); _loadTrips(); },
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _liveTrips.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text("Aucune course trouvée", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      ]))
                    : ListView.builder(
                        itemCount: _liveTrips.length,
                        itemBuilder: (context, index) => _buildTripCard(_liveTrips[index], isDark),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, bool isDark) {
    final sc = _statusColor(trip['status']);
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTripDetails(trip),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 4, height: 60, decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_statusLabel(trip['status']), style: TextStyle(color: sc, fontWeight: FontWeight.w600, fontSize: 11)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.circle, size: 8, color: Colors.green.shade400), const SizedBox(width: 6),
                Expanded(child: Text(trip['pickup_address']?.toString() ?? '—', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.circle, size: 8, color: Colors.red.shade400), const SizedBox(width: 6),
                Expanded(child: Text(trip['dropoff_address']?.toString() ?? '—', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Client", style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
              const SizedBox(height: 4),
              Text(trip['user_name']?.toString() ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            ])),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Chauffeur", style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
              const SizedBox(height: 4),
              Text(trip['driver_name']?.toString() ?? 'En attente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            ])),
            SizedBox(width: 100, child: Text("${trip['fare_amount'] ?? '—'} HTG", textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981)))),
          ]),
        ),
      ),
    );
  }
}
