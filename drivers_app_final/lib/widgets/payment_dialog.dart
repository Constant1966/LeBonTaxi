import 'package:flutter/material.dart';
import 'package:drivers_app/services/local_notification_service.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/pages/dashboard.dart';
import 'package:drivers_app/widgets/rating_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dialog de paiement — Cash / MonCash / NatCash
class PaymentDialog extends StatefulWidget {
  final String fareAmount;
  final String tripId;
  final String clientName;

  const PaymentDialog({
    super.key,
    required this.fareAmount,
    required this.tripId,
    required this.clientName,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  bool _waitingForConfirmation = false;
  bool _paymentConfirmed = false;
  RealtimeChannel? _paymentChannel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _paymentChannel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectCashPayment() async {
    setState(() {
      _waitingForConfirmation = true;
    });

    try {
      await Supabase.instance.client.from('trip_requests').update({
        'payment_method': 'cash',
        'payment_status': 'pending',
      }).eq('trip_id', widget.tripId);

      _listenForPaymentConfirmation();
    } catch (e) {
      if (mounted) {
        setState(() => _waitingForConfirmation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _listenForPaymentConfirmation() {
    _paymentChannel?.unsubscribe();

    _paymentChannel = Supabase.instance.client
        .channel('payment_confirm_${widget.tripId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trip_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trip_id',
        value: widget.tripId,
      ),
      callback: (payload) async {
        if (!mounted) return;
        final data = payload.newRecord;
        if (data['payment_status'] == 'confirmed') {
          await LocalNotificationService.showPaymentNotification(
            tripId: widget.tripId,
            amount: widget.fareAmount,
          );
          if (mounted) {
            setState(() {
              _paymentConfirmed = true;
              _waitingForConfirmation = false;
            });
          }
        }
      },
    ).subscribe();
  }

  Future<void> _confirmCashReceived() async {
    try {
      await Supabase.instance.client.from('trip_requests').update({
        'payment_status': 'completed',
        'payment_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', widget.tripId);

      if (mounted) {
        // Fermer le dialogue de paiement
        Navigator.pop(context);
        
        // Afficher l'évaluation
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RatingDialog(
            tripId: widget.tripId,
            clientName: widget.clientName,
            onRated: () {
              // Après évaluation, aller au Dashboard
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Dashboard()),
                (route) => false,
              );
            },
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur confirmation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header avec gradient + logo ───
              _buildHeader(),

              // ─── Contenu ───
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_paymentConfirmed)
                      _buildConfirmedState()
                    else if (_waitingForConfirmation)
                      _buildWaitingState()
                    else
                      _buildPaymentMethods(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header élégant avec gradient, logo et montant ───
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Montant
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paymentConfirmed ? "Paiement confirmé" : "Course terminée",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.fareAmount,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "HTG",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/final_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.local_taxi,
                  color: AppColors.primary,
                  size: 30,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sélection du mode de paiement ───
  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mode de paiement",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),

        _PaymentOption(
          icon: Icons.payments_outlined,
          label: "Cash",
          enabled: true,
          onTap: _selectCashPayment,
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          icon: Icons.phone_android_rounded,
          label: "MonCash",
          tag: "Bientôt",
          enabled: false,
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          icon: Icons.phone_android_rounded,
          label: "NatCash",
          tag: "Bientôt",
          enabled: false,
        ),

        const SizedBox(height: 14),

        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Annuler",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ─── En attente du client ───
  Widget _buildWaitingState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text(
                "Cash",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary.withOpacity(0.5),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          "En attente du client...",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Le client doit confirmer le paiement",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ─── Paiement confirmé ───
  Widget _buildConfirmedState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Le client a confirmé le paiement",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _confirmCashReceived,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Confirmer la réception",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Option de paiement ───
class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tag;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    this.tag,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? AppColors.border : AppColors.borderLight,
            ),
            color: enabled ? Colors.white : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? AppColors.primary : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.textPrimary : Colors.grey.shade400,
                  ),
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}