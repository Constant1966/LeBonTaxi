import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TripProgressCard extends StatelessWidget {
  final String tripStatus;
  final String buttonText;
  final Color buttonColor;
  final String durationText;
  final String distanceText;
  final String userName;
  final String pickupAddress;
  final String dropoffAddress;
  final VoidCallback onCallPressed;
  final VoidCallback onActionPressed;
  final VoidCallback? onNavigatePressed;
  final VoidCallback? onChatPressed;

  const TripProgressCard({
    super.key,
    required this.tripStatus,
    required this.buttonText,
    required this.buttonColor,
    required this.durationText,
    required this.distanceText,
    required this.userName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.onCallPressed,
    required this.onActionPressed,
    this.onNavigatePressed,
    this.onChatPressed,
  });

  String _getStatusText() {
    switch (tripStatus) {
      case "accepted":
        return "En route vers le client";
      case "arrived":
        return "Arrivé chez le client";
      case "ontrip":
        return "Course en cours";
      default:
        return "";
    }
  }

  Color _getStatusColor() {
    switch (tripStatus) {
      case "accepted":
        return AppColors.primary;
      case "arrived":
        return AppColors.success;
      case "ontrip":
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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

              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ETA + Distance
              if (durationText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        durationText,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      const Icon(Icons.route, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        distanceText,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // User Info + action buttons
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Client",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton Chat
                  if (onChatPressed != null) ...[
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.info,
                      onPressed: onChatPressed!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Bouton Appel
                  _buildActionButton(
                    icon: Icons.phone,
                    color: AppColors.success,
                    onPressed: onCallPressed,
                  ),
                  const SizedBox(width: 8),
                  // Bouton Naviguer
                  if (onNavigatePressed != null)
                    _buildActionButton(
                      icon: Icons.near_me_rounded,
                      color: AppColors.primary,
                      onPressed: onNavigatePressed!,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Pickup Address
              _buildAddressRow(
                icon: Icons.location_on,
                iconColor: AppColors.success,
                label: "Départ",
                address: pickupAddress,
              ),

              const SizedBox(height: 12),

              // Dropoff Address
              _buildAddressRow(
                icon: Icons.flag,
                iconColor: AppColors.error,
                label: "Destination",
                address: dropoffAddress,
              ),

              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}