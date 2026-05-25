import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:users_app/theme/app_colors.dart';

/// Partage de course en français
class TripShareService {
  /// Partager les détails de la course
  static Future<void> shareTrip({
    required String driverName,
    required String carDetails,
    required String carNumber,
    required String pickupAddress,
    required String destinationAddress,
    required String fareAmount,
    required String eta,
  }) async {
    final message = '''
🚕 *Ma course Le Bon Taxi*

👤 Chauffeur : $driverName
🚗 Véhicule : $carDetails
🔢 Plaque : $carNumber

📍 Départ : $pickupAddress
📍 Arrivée : $destinationAddress

💰 Tarif estimé : $fareAmount
⏱️ Durée estimée : $eta

📱 Envoyé depuis Le Bon Taxi
''';

    try {
      await Share.share(
        message,
        subject: 'Ma course Le Bon Taxi',
      );
    } catch (e) {
      print('❌ Erreur partage: $e');
    }
  }
}

/// Widget bottom sheet pour partage
class TripShareSheet extends StatelessWidget {
  final String driverName;
  final String carDetails;
  final String carNumber;
  final String pickupAddress;
  final String destinationAddress;
  final String fareAmount;
  final String eta;

  const TripShareSheet({
    super.key,
    required this.driverName,
    required this.carDetails,
    required this.carNumber,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fareAmount,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Icon(Icons.share, color: AppColors.primary, size: 40),
          const SizedBox(height: 12),

          const Text(
            'Partager ma course',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Text(
            'Partagez les détails de votre course avec un proche',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Trip summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'Chauffeur', driverName),
                const Divider(height: 16),
                _buildInfoRow(Icons.directions_car, 'Véhicule', '$carDetails • $carNumber'),
                const Divider(height: 16),
                _buildInfoRow(Icons.location_on, 'Vers', destinationAddress),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                TripShareService.shareTrip(
                  driverName: driverName,
                  carDetails: carDetails,
                  carNumber: carNumber,
                  pickupAddress: pickupAddress,
                  destinationAddress: destinationAddress,
                  fareAmount: fareAmount,
                  eta: eta,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share),
              label: const Text('Partager maintenant', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
