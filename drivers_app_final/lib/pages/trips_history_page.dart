import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TripsHistoryPage extends StatefulWidget {
  const TripsHistoryPage({super.key});

  @override
  State<TripsHistoryPage> createState() => _TripsHistoryPageState();
}

class _TripsHistoryPageState extends State<TripsHistoryPage> {
  List<Map<String, dynamic>> _completedTrips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTrips();
  }

  Future<void> _loadCompletedTrips() async {
    try {
      final trips = await SupabaseService.getDriverTripsHistory(
        status: 'completed',
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _completedTrips = trips;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Erreur chargement historique: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1B4B) : AppColors.primary,
        elevation: 0,
        title: const Text(
          'Historique des Courses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _completedTrips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        "Aucune course terminée",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Vos courses terminées apparaîtront ici",
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCompletedTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _completedTrips.length,
                    itemBuilder: ((context, index) {
                      final trip = _completedTrips[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with Fare
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 16,
                                            color: AppColors.success),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Terminée",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "${trip['fare_amount']?.toString() ?? '0'} HTG",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Pickup
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.location_on,
                                        color: AppColors.success, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Départ",
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: theme.textTheme
                                                    .bodySmall?.color,
                                                fontWeight:
                                                    FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip['pickup_address']
                                                  ?.toString() ??
                                              "Adresse non disponible",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.textTheme
                                                .bodyLarge?.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Dropoff
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEC4899)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.flag,
                                        color: Color(0xFFEC4899), size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Arrivée",
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: theme.textTheme
                                                    .bodySmall?.color,
                                                fontWeight:
                                                    FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text(
                                          trip['dropoff_address']
                                                  ?.toString() ??
                                              "Adresse non disponible",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.textTheme
                                                .bodyLarge?.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Distance & Duration
                              if (trip['distance_km'] != null ||
                                  trip['duration_minutes'] != null) ...[
                                const SizedBox(height: 12),
                                Divider(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (trip['distance_km'] != null) ...[
                                      Icon(Icons.straighten,
                                          size: 16,
                                          color: theme
                                              .textTheme.bodySmall?.color),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${trip['distance_km'].toStringAsFixed(1)} km",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme
                                                .bodySmall?.color),
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    if (trip['duration_minutes'] !=
                                        null) ...[
                                      Icon(Icons.access_time,
                                          size: 16,
                                          color: theme
                                              .textTheme.bodySmall?.color),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${trip['duration_minutes']} min",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme
                                                .bodySmall?.color),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
    );
  }
}