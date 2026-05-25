import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';

/// Carte d'information chauffeur premium
class DriverInfoCard extends StatelessWidget {
  final String driverName;
  final String driverPhone;
  final String driverPhoto;
  final String carDetails;
  final String carNumber;
  final String carColor;
  final String driverRating;
  final String? carPhoto;
  final String? driverETA;
  final double? driverDistanceKm;
  final String tripStatus;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onEmergency;
  final VoidCallback? onShareTrip;
  final VoidCallback? onCancel;

  const DriverInfoCard({
    super.key,
    required this.driverName,
    required this.driverPhone,
    required this.driverPhoto,
    required this.carDetails,
    required this.carNumber,
    this.carColor = '',
    required this.driverRating,
    this.carPhoto,
    this.driverETA,
    this.driverDistanceKm,
    required this.tripStatus,
    required this.onCall,
    required this.onChat,
    required this.onEmergency,
    this.onShareTrip,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const SizedBox(height: 16),

              // ✅ Status badge + ETA
              _buildStatusRow(),
              const SizedBox(height: 20),

              // ✅ Driver info card
              _buildDriverInfoRow(),
              const SizedBox(height: 16),

              // ✅ Vehicle info
              _buildVehicleInfo(),
              const SizedBox(height: 16),

              // ✅ Action buttons
              _buildActionButtons(),

              // ✅ Share trip
              if (onShareTrip != null) ...[
                const SizedBox(height: 12),
                _buildShareButton(),
              ],

              // ✅ Vehicle photo
              if (carPhoto != null && carPhoto!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildVehiclePhoto(),
              ],

              // ✅ Cancel button
              if (onCancel != null && tripStatus != 'ended') ...[
                const SizedBox(height: 16),
                _buildCancelButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusText,
                style: TextStyle(
                  color: _statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (driverETA != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.info),
                const SizedBox(width: 4),
                Text(
                  'ETA: $driverETA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDriverInfoRow() {
    return Row(
      children: [
        // Photo chauffeur (plus grande)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            image: driverPhoto.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(driverPhoto),
                    fit: BoxFit.cover,
                  )
                : null,
            color: driverPhoto.isEmpty ? AppColors.primary.withOpacity(0.1) : null,
          ),
          child: driverPhoto.isEmpty
              ? const Icon(Icons.person, size: 36, color: AppColors.primary)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driverName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              // Rating avec étoiles
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final rating = double.tryParse(driverRating) ?? 5.0;
                    return Icon(
                      index < rating.floor()
                          ? Icons.star
                          : (index < rating ? Icons.star_half : Icons.star_border),
                      color: AppColors.warning,
                      size: 18,
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    driverRating,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              if (driverDistanceKm != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${driverDistanceKm!.toStringAsFixed(1)} km de vous',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carDetails,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if (carColor.isNotEmpty)
                  Text(
                    carColor,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              carNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildActionBtn(Icons.phone, 'Appeler', AppColors.success, onCall)),
        const SizedBox(width: 10),
        Expanded(child: _buildActionBtn(Icons.chat_bubble_outline, 'Message', AppColors.primary, onChat)),
        const SizedBox(width: 10),
        Expanded(child: _buildActionBtn(Icons.emergency, 'Urgence', AppColors.error, onEmergency)),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onShareTrip,
        icon: const Icon(Icons.share, size: 20),
        label: const Text('Partager ma course'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.info,
          side: const BorderSide(color: AppColors.info),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildVehiclePhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.directions_car, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Votre véhicule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 180,
            child: Image.network(
              carPhoto!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Photo non disponible', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onCancel,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'ANNULER LA COURSE',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String get _statusText {
    switch (tripStatus) {
      case 'accepted':
        return 'Chauffeur en route';
      case 'arrived':
        return 'Chauffeur arrivé';
      case 'ontrip':
        return 'Course en cours';
      case 'ended':
        return 'Course terminée';
      default:
        return 'En attente';
    }
  }

  Color get _statusColor {
    switch (tripStatus) {
      case 'accepted':
        return AppColors.info;
      case 'arrived':
        return AppColors.warning;
      case 'ontrip':
        return AppColors.success;
      case 'ended':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}
