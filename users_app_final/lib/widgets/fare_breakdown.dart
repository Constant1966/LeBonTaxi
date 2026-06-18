import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';
import '../global/global_var_supabase.dart';

/// Widget de décomposition du tarif
class FareBreakdown extends StatelessWidget {
  final double distanceKm;
  final double? baseFare;
  final double? perKmRate;
  final String trafficLabel;
  final double trafficMultiplier;
  final double discountPercentage;
  final double referralDiscountValue;
  final String? referralDiscountType;

  const FareBreakdown({
    super.key,
    required this.distanceKm,
    this.baseFare,
    this.perKmRate,
    this.trafficLabel = 'Normal',
    this.trafficMultiplier = 1.0,
    this.discountPercentage = 0.0,
    this.referralDiscountValue = 0.0,
    this.referralDiscountType,
  });

  double get actualBaseFare => baseFare ?? globalBaseFare;
  double get actualPerKmRate => perKmRate ?? globalPerKmRate;

  double get distanceFare => distanceKm * actualPerKmRate;
  double get subtotal => actualBaseFare + distanceFare;
  double get trafficSurcharge => subtotal * (trafficMultiplier - 1.0);
  double get totalFareBeforeDiscount => subtotal + trafficSurcharge;
  double get subscriptionDiscountAmount => totalFareBeforeDiscount * (discountPercentage / 100.0);
  
  double get referralDiscountAmount {
    if (referralDiscountValue <= 0) return 0.0;
    if (referralDiscountType == 'percentage') {
      return (totalFareBeforeDiscount - subscriptionDiscountAmount) * (referralDiscountValue / 100.0);
    } else {
      return referralDiscountValue;
    }
  }

  double get totalFare => totalFareBeforeDiscount - subscriptionDiscountAmount - referralDiscountAmount;
  int get totalRounded => totalFare.ceil();
  int get minimumFare => globalMinimumFare.toInt();
  int get finalFare => totalRounded < minimumFare ? minimumFare : totalRounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Estimation du tarif',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Base fare
          _buildRow('Prise en charge', '${actualBaseFare.round()} HTG'),
          const SizedBox(height: 8),

          // Distance fare
          _buildRow(
            'Distance (${distanceKm.toStringAsFixed(1)} km × ${actualPerKmRate.round()} HTG)',
            '${distanceFare.round()} HTG',
          ),

          // Traffic surcharge
          if (trafficMultiplier > 1.0) ...[
            const SizedBox(height: 8),
            _buildRow(
              'Trafic ($trafficLabel)',
              '+${trafficSurcharge.round()} HTG',
              valueColor: AppColors.warning,
            ),
          ],

          // Subscription discount
          if (discountPercentage > 0) ...[
            const SizedBox(height: 8),
            _buildRow(
              'Réduction Abonnement (${discountPercentage.round()}%)',
              '-${subscriptionDiscountAmount.round()} HTG',
              valueColor: AppColors.success,
            ),
          ],

          // Referral discount
          if (referralDiscountValue > 0) ...[
            const SizedBox(height: 8),
            _buildRow(
              referralDiscountType == 'percentage'
                  ? 'Réduction Parrainage (${referralDiscountValue.round()}%)'
                  : 'Réduction Parrainage',
              '-${referralDiscountAmount.round()} HTG',
              valueColor: Colors.purple.shade600,
            ),
          ],

          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.border,
          ),
          const SizedBox(height: 12),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total estimé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$finalFare HTG',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          if (totalRounded < minimumFare) ...[
            const SizedBox(height: 8),
            Text(
              '* Tarif minimum appliqué: $minimumFare HTG',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
