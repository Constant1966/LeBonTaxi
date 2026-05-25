import 'package:flutter/material.dart';
import 'package:users_app/services/network_service.dart';
import 'package:users_app/theme/app_colors.dart';

/// Bannière affichée en haut quand le réseau est hors ligne
class OfflineBanner extends StatelessWidget {
  final NetworkStatus status;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == NetworkStatus.online) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: status == NetworkStatus.offline
            ? AppColors.error
            : AppColors.warning,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (status == NetworkStatus.offline
                    ? AppColors.error
                    : AppColors.warning)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            status == NetworkStatus.offline ? Icons.wifi_off : Icons.signal_wifi_bad,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status == NetworkStatus.offline
                  ? 'Mode hors ligne'
                  : 'Connexion instable',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
