import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../methods/common_methods.dart';

class SubscriptionPlansPage extends StatefulWidget {
  static const String id = "\webPageSubscriptionPlans";

  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final supabase = Supabase.instance.client;
  final _commonMethods = CommonMethods();

  Future<void> _deletePlan(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dlgDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dlgDark ? AppColors.darkCard : Colors.white,
          title: Text("Supprimer l'abonnement", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87)),
          content: Text("Êtes-vous sûr de vouloir supprimer ce plan d'abonnement ?", style: TextStyle(color: dlgDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      try {
        await supabase.from('subscription_plans').delete().eq('id', id);
        if (mounted) {
          _commonMethods.showSnackBar(context, "Plan supprimé avec succès");
        }
      } catch (e) {
        if (mounted) {
          _commonMethods.showSnackBar(context, "Erreur: $e", isError: true);
        }
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? plan]) {
    final isEditing = plan != null;
    final nameController = TextEditingController(text: isEditing ? plan['name'] : '');
    final priceController = TextEditingController(text: isEditing ? plan['price']?.toString() : '');
    final durationController = TextEditingController(text: isEditing ? plan['duration_days']?.toString() : '');
    final discountController = TextEditingController(text: isEditing ? plan['discount_percentage']?.toString() : '');
    bool isActive = isEditing ? (plan['is_active'] ?? true) : true;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? "Modifier l'abonnement" : "Ajouter un abonnement", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(labelText: "Nom du plan (ex: Premium 30 Jours)", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      validator: (val) => val!.isEmpty ? "Requis" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(labelText: "Prix (HTG)", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty || double.tryParse(val) == null ? "Requis / Invalide" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: durationController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(labelText: "Durée (jours)", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty || int.tryParse(val) == null ? "Requis / Invalide" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: discountController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(labelText: "Réduction Course (%)", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty || double.tryParse(val) == null ? "Requis / Invalide" : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text("Actif"),
                      value: isActive,
                      onChanged: (val) {
                        setDialogState(() {
                          isActive = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    final updates = {
                      'name': nameController.text,
                      'price': double.parse(priceController.text),
                      'duration_days': int.parse(durationController.text),
                      'discount_percentage': double.parse(discountController.text),
                      'is_active': isActive,
                    };

                    try {
                      if (isEditing) {
                        await supabase.from('subscription_plans').update(updates).eq('id', plan['id']);
                      } else {
                        await supabase.from('subscription_plans').insert(updates);
                      }
                      
                      if (mounted) {
                        _commonMethods.showSnackBar(context, isEditing ? "Modifié avec succès" : "Ajouté avec succès");
                      }
                    } catch (e) {
                      if (mounted) {
                        _commonMethods.showSnackBar(context, "Erreur: $e", isError: true);
                      }
                    }
                  }
                },
                child: const Text("Sauvegarder"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Abonnements Le Bon Taxi Plus",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Nouveau Plan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('subscription_plans').stream(primaryKey: ['id']).order('price'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Erreur: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final plans = snapshot.data ?? [];

                  if (plans.isEmpty) {
                    return const Center(child: Text("Aucun plan d'abonnement trouvé."));
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return Card(
                        elevation: 0,
                        color: isDark ? AppColors.darkCard : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
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
                                      plan['name']?.toString() ?? "Sans nom",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (plan['is_active'] ?? true) 
                                        ? (isDark ? const Color(0xFF10B981).withOpacity(0.15) : Colors.green.shade100) 
                                        : (isDark ? const Color(0xFFEF4444).withOpacity(0.15) : Colors.red.shade100),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (plan['is_active'] ?? true) ? "Actif" : "Inactif",
                                      style: TextStyle(
                                        color: (plan['is_active'] ?? true) 
                                          ? (isDark ? const Color(0xFF34D399) : Colors.green.shade700) 
                                          : (isDark ? const Color(0xFFF87171) : Colors.red.shade700),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text("${plan['price']} HTG / ${plan['duration_days']} jours", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                              const SizedBox(height: 8),
                              Text("- ${plan['discount_percentage']}% sur chaque course", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                              
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showAddEditDialog(plan),
                                    tooltip: "Modifier",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deletePlan(plan['id'].toString()),
                                    tooltip: "Supprimer",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
