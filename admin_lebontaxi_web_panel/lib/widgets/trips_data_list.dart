import '../constants/app_colors.dart';
import '../methods/common_methods.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Widget pour afficher la liste des trajets
class TripsDataList extends StatefulWidget {
  final String searchQuery;
  
  const TripsDataList({super.key, this.searchQuery = ""});

  @override
  State<TripsDataList> createState() => _TripsDataListState();
}

class _TripsDataListState extends State<TripsDataList>
{
  final supabase = Supabase.instance.client;
  CommonMethods cMethods = CommonMethods();

  // Lance Google Maps pour afficher l'itinéraire du trajet
  launchGoogleMapFromSourceToDestination(pickUpLat, pickUpLng, dropOffLat, dropOffLng) async
  {
    String directionAPIUrl = "https://www.google.com/maps/dir/?api=1&origin=$pickUpLat,$pickUpLng&destination=$dropOffLat,$dropOffLng&dir_action=navigate";

    if(await canLaunchUrl(Uri.parse(directionAPIUrl)))
    {
      await launchUrl(Uri.parse(directionAPIUrl));
    }
    else
    {
      if (mounted) {
        cMethods.showSnackBar(
          context,
          "Impossible de lancer Google Maps",
          isError: true,
        );
      }
    }
  }

  // Affiche une boîte de dialogue avec les détails du trajet
  void _showTripDetailsDialog(Map<String, dynamic> trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.route, color: Color(0xFF6366F1)),
              const SizedBox(width: 12),
              Text("Détails du trajet", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow("ID du trajet", trip["trip_id"]?.toString() ?? "N/A", isDark),
                Divider(color: isDark ? AppColors.darkBorder : null),
                _buildDetailRow("Client", trip["user_name"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Tél. client", trip["user_phone"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Chauffeur", trip["driver_name"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Voiture", "${trip['car_model'] ?? ''} ${trip['car_number'] ?? ''}".trim(), isDark),
                Divider(color: isDark ? AppColors.darkBorder : null),
                _buildDetailRow("Départ", trip["pickup_address"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Arrivée", trip["dropoff_address"]?.toString() ?? "N/A", isDark),
                Divider(color: isDark ? AppColors.darkBorder : null),
                _buildDetailRow("Date et heure", trip["created_at"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Distance", trip["distance"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Durée", trip["duration"]?.toString() ?? "N/A", isDark),
                _buildDetailRow("Montant", "${trip["fare_amount"]} HTG", isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
               "Fermer",
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                
                String pickUpLat = trip["pickup_latitude"]?.toString() ?? "";
                String pickUpLng = trip["pickup_longitude"]?.toString() ?? "";
                String dropOffLat = trip["dropoff_latitude"]?.toString() ?? "";
                String dropOffLng = trip["dropoff_longitude"]?.toString() ?? "";

                if (pickUpLat.isNotEmpty && pickUpLng.isNotEmpty && dropOffLat.isNotEmpty && dropOffLng.isNotEmpty) {
                  launchGoogleMapFromSourceToDestination(
                    pickUpLat,
                    pickUpLng,
                    dropOffLat,
                    dropOffLng,
                  );
                } else {
                  cMethods.showSnackBar(
                    context,
                    "Données de localisation incomplètes",
                    isError: true,
                  );
                }
              },
              icon: const Icon(Icons.map, size: 18),
              label: const Text("Voir sur la carte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget pour construire une ligne de détail dans la boîte de dialogue
  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('trip_requests').stream(primaryKey: ['id']),
      builder: (context, snapshot)
      {
        if(snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text("Une erreur est survenue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ])));
        }

        if(snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Aucun trajet trouvé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ])));
        }

        // Filtrer uniquement les trajets terminés
        List<Map<String, dynamic>> itemsList = snapshot.data!.where((t) => t['status'] == 'completed').toList();

        if (widget.searchQuery.isNotEmpty) {
          itemsList = itemsList.where((item) {
            final tripId = item["trip_id"]?.toString().toLowerCase() ?? "";
            final userName = item["user_name"]?.toString().toLowerCase() ?? "";
            final driverName = item["driver_name"]?.toString().toLowerCase() ?? "";
            return tripId.contains(widget.searchQuery) || userName.contains(widget.searchQuery) || driverName.contains(widget.searchQuery);
          }).toList();
        }

        if (itemsList.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(widget.searchQuery.isNotEmpty ? "Aucun résultat trouvé" : "Aucun trajet terminé", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ])));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemsList.length,
          itemBuilder: ((context, index) {
            final trip = itemsList[index];
            
            return Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.darkCard : Colors.grey.shade100))),
              child: Row(
                children: [
                  cMethods.data(2, Text(trip["trip_id"]?.toString() ?? "N/A", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)), isDark: isDark),
                  cMethods.data(1, Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      child: Text(
                        (trip["user_name"]?.toString() != null && trip["user_name"].toString().isNotEmpty) ? trip["user_name"].toString()[0].toUpperCase() : "?",
                        style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trip["user_name"]?.toString() ?? "N/A", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                  ]), isDark: isDark),
                  cMethods.data(1, Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      child: const Icon(Icons.local_taxi, color: Color(0xFF6366F1), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trip["driver_name"]?.toString() ?? "N/A", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                  ]), isDark: isDark),
                  cMethods.data(1, Text("${trip['car_model'] ?? ''} ${trip['car_number'] ?? ''}".trim(), style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis), isDark: isDark),
                  cMethods.data(1, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trip["created_at"]?.toString().split('T').first ?? "", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(trip["created_at"]?.toString().split('T').last.split('.').first ?? '', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                  ]), isDark: isDark),
                  cMethods.data(1, Text("${trip["fare_amount"] ?? "0"} HTG", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981), fontSize: 14)), isDark: isDark),
                  cMethods.data(1, ElevatedButton.icon(
                    onPressed: () => _showTripDetailsDialog(trip),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text("Détails", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  ), isDark: isDark),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
