import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/models/subscription_plan_model.dart';
import '../global/global_var_supabase.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  late Future<List<SubscriptionPlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = SupabaseService.fetchSubscriptionPlans();
  }

  void _subscribeToPlan(SubscriptionPlan plan) async {
    // 1. Simulation du processus de paiement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Traitement du paiement..."),
            ],
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    // 2. Mise à jour de la base de données
    if (SupabaseService.userId != null) {
      try {
        final startDate = DateTime.now();
        final expirationDate = startDate.add(Duration(days: plan.durationDays));
        
        await SupabaseService.supabase.from('users').update({
          'subscription_plan_id': plan.id,
          'subscription_start_date': startDate.toIso8601String(),
          'subscription_end_date': expirationDate.toIso8601String(),
        }).eq('id', SupabaseService.userId!);

        // 3. Créer l'enregistrement dans l'historique
        await SupabaseService.createSubscriptionRecord(
          planId: plan.id,
          planName: plan.name,
          amountPaid: plan.price,
          startDate: startDate,
          endDate: expirationDate,
          currency: plan.currency,
        );

        // 4. Recharger le statut d'abonnement (met à jour les globales)
        await SupabaseService.loadUserSubscriptionStatus();
        
        if (!mounted) return;
        Navigator.pop(context); // Fermer le loader
        
        // 5. Succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text("Abonnement ${plan.name} activé avec succès !"),
             backgroundColor: AppColors.success,
          ),
        );
        
        setState(() {}); // Rafraichir l'UI
      } catch(e) {
        if (!mounted) return;
        Navigator.pop(context); // Fermer le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text("Erreur: ${e.toString()}"),
             backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Le Bon Taxi Plus"),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder<List<SubscriptionPlan>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text("Erreur de chargement: ${snapshot.error}"));
          }
          
          final plans = snapshot.data ?? [];
          
          if (plans.isEmpty) {
             return const Center(child: Text("Aucun forfait disponible pour le moment."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isCurrentPlan = plan.id == userSubscriptionPlanId && isUserSubscribed;
              
              return _buildPlanCard(plan, isCurrentPlan);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool isCurrentPlan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isCurrentPlan
            ? const LinearGradient(colors: [AppColors.success, Color(0xFF66BB6A)])
            : const LinearGradient(colors: [Color(0xFF1E1E2E), Color(0xFF2D2D3A)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isCurrentPlan ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Actif",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "${plan.price.round()} ${plan.currency}",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "/ ${plan.durationDays} jours",
                  style: const TextStyle(color: Colors.white70),
                )
              ],
            ),
            if (plan.discountPercentage > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "${plan.discountPercentage}% de réduction",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            // ✅ Liste des avantages du forfait
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: isCurrentPlan ? Colors.white70 : AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrentPlan ? null : () => _subscribeToPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan ? Colors.white.withOpacity(0.5) : AppColors.primary,
                  foregroundColor: isCurrentPlan ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isCurrentPlan ? "Forfait Actuel" : "S'abonner",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
