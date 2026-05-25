import 'dart:async';
import 'package:flutter/material.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';

class PaymentDialogSupabase extends StatefulWidget {
  final String fareAmount;
  final String tripID;
  final String driverID;
  final String driverName;
  final String distance;
  final String duration;

  const PaymentDialogSupabase({
    super.key,
    required this.fareAmount,
    required this.tripID,
    required this.driverID,
    required this.driverName,
    this.distance = '',
    this.duration = '',
  });

  @override
  State<PaymentDialogSupabase> createState() => _PaymentDialogSupabaseState();
}

class _PaymentDialogSupabaseState extends State<PaymentDialogSupabase> {
  String _selectedMethod = "cash";
  bool _isWaiting = false;
  bool _hasConfirmed = false;
  bool _hasError = false;
  String _errorMessage = '';
  StreamSubscription? _statusSubscription;
  Timer? _timeoutTimer;
  int _waitingSeconds = 0;
  Timer? _countdownTimer;

  static const int _paymentTimeoutSeconds = 120; // 2 minutes

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: _hasError
            ? _buildError()
            : _isWaiting
                ? _buildWaiting()
                : _buildSelection(),
      ),
    );
  }

  Widget _buildSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Montant principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          widget.fareAmount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          "HTG",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Montant de la course",
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),

            // ✅ NOUVEAU: Récapitulatif de la course
            if (widget.distance.isNotEmpty || widget.duration.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Récapitulatif",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.distance.isNotEmpty)
                      _buildSummaryRow(
                        Icons.straighten,
                        "Distance",
                        widget.distance,
                      ),
                    if (widget.duration.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        Icons.access_time,
                        "Durée",
                        widget.duration,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      Icons.person,
                      "Chauffeur",
                      widget.driverName,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              "Choisir le mode de paiement",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildOption(
              "Paiement en Espèces",
              "cash",
              Icons.payments_rounded,
              AppColors.success,
              true,
            ),
            const SizedBox(height: 14),
            _buildOption(
              "MonCash",
              "moncash",
              Icons.phone_android,
              const Color(0xFFE53935),
              false,
            ),
            const SizedBox(height: 14),
            _buildOption(
              "NatCash",
              "natcash",
              Icons.account_balance_wallet,
              const Color(0xFF1976D2),
              false,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _hasConfirmed ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "CONFIRMER LE PAIEMENT",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    final remaining = _paymentTimeoutSeconds - _waitingSeconds;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "En attente de confirmation...",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Le chauffeur doit confirmer\nla réception du paiement",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // ✅ Compteur
          Text(
            remaining > 0
                ? "Temps restant: ${remaining}s"
                : "Timeout...",
            style: TextStyle(
              fontSize: 13,
              color: remaining > 30
                  ? Colors.grey.shade500
                  : AppColors.warning,
              fontWeight: remaining <= 30 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 24),
          // ✅ Bouton de secours si timeout
          if (_waitingSeconds >= 60)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _forceCompletePayment,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Valider sans attendre",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ NOUVEAU: Écran d'erreur avec retry
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Erreur de paiement",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _hasConfirmed = false;
                  _errorMessage = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Réessayer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    String label,
    String value,
    IconData icon,
    Color color,
    bool enabled,
  ) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedMethod = value) : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled
              ? (selected ? color.withOpacity(0.12) : Colors.white)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? (selected ? color : Colors.grey.shade300)
                : Colors.grey.shade300,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: enabled ? color.withOpacity(0.15) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: enabled ? color : Colors.grey.shade500,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.black : Colors.grey.shade500,
                ),
              ),
            ),
            if (!enabled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Bientôt",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: selected ? color : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_hasConfirmed) return;
    setState(() => _hasConfirmed = true);

    print("💳 Confirmation paiement");

    try {
      // ✅ FIX: Utiliser 'pending' pour être compatible avec le driver app
      // Le driver écoute 'payment_status' == 'confirmed' pour afficher la notification
      // ✅ FIX: Le user confirme le paiement → 'confirmed'
      // Le driver écoute 'confirmed' → affiche "Client a confirmé"
      // Le driver valide la réception → 'completed'
      await SupabaseService.supabase.from('trip_requests').update({
        'payment_method': _selectedMethod,
        'payment_status': 'confirmed',
      }).eq('trip_id', widget.tripID);

      // Créer notification pour le chauffeur
      try {
        await SupabaseService.createPaymentNotification(
          driverId: widget.driverID,
          tripId: widget.tripID,
          fareAmount: widget.fareAmount,
          paymentMethod: _selectedMethod,
        );
      } catch (e) {
        print("⚠️ Erreur notification paiement (non bloquante): $e");
      }

      setState(() {
        _isWaiting = true;
        _waitingSeconds = 0;
      });

      // ✅ Démarrer le compteur
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _waitingSeconds++);
      });

      // ✅ Timeout de 120s
      _timeoutTimer = Timer(
        const Duration(seconds: _paymentTimeoutSeconds),
        () {
          if (mounted && _isWaiting) {
            _forceCompletePayment();
          }
        },
      );

      // Écouter les changements de statut de paiement
      _statusSubscription = SupabaseService.supabase
          .from('trip_requests')
          .stream(primaryKey: ['id'])
          .eq('trip_id', widget.tripID)
          .listen((data) {
        if (data.isEmpty) return;

        final trip = data.first;
        final status = trip['payment_status'] as String?;

        // ✅ FIX: Accepter 'confirmed' OU 'completed' (driver peut envoyer les deux)
        if (status == 'confirmed' || status == 'completed') {
          print("✅ PAIEMENT CONFIRMÉ !");
          _statusSubscription?.cancel();
          _timeoutTimer?.cancel();
          _countdownTimer?.cancel();

          if (mounted) {
            Navigator.pop(context, {
              'paid': true,
              'tripID': widget.tripID,
              'driverID': widget.driverID,
              'driverName': widget.driverName,
            });
          }
        }
      });
    } catch (e) {
      print("❌ Erreur paiement: $e");
      if (mounted) {
        setState(() {
          _isWaiting = false;
          _hasConfirmed = false;
          _hasError = true;
          _errorMessage = "Impossible de confirmer le paiement.\n$e";
        });
      }
    }
  }

  /// ✅ NOUVEAU: Forcer la validation du paiement (cash) après timeout
  Future<void> _forceCompletePayment() async {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _statusSubscription?.cancel();

    try {
      // Marquer comme confirmé côté utilisateur
      await SupabaseService.supabase.from('trip_requests').update({
        'payment_status': 'confirmed',
        'payment_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', widget.tripID);

      if (mounted) {
        Navigator.pop(context, {
          'paid': true,
          'tripID': widget.tripID,
          'driverID': widget.driverID,
          'driverName': widget.driverName,
        });
      }
    } catch (e) {
      print("❌ Erreur forceComplete: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isWaiting = false;
          _errorMessage = "Erreur lors de la validation du paiement.\n$e";
        });
      }
    }
  }
}