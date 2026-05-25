import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_log_service.dart';

class PricingDiscountsPage extends StatefulWidget {
  static const String id = "\\webPagePricingDiscounts";
  const PricingDiscountsPage({super.key});

  @override
  State<PricingDiscountsPage> createState() => _PricingDiscountsPageState();
}

class _PricingDiscountsPageState extends State<PricingDiscountsPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  // Pricing controllers
  final _formKey = GlobalKey<FormState>();
  final _baseFareCtrl = TextEditingController();
  final _perKmCtrl = TextEditingController();
  final _perMinuteCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _minimumFareCtrl = TextEditingController();
  final _waitingPerMinCtrl = TextEditingController();
  final _nightSurchargeCtrl = TextEditingController();
  bool _isLoadingPricing = true;
  bool _isSavingPricing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPricing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseFareCtrl.dispose();
    _perKmCtrl.dispose();
    _perMinuteCtrl.dispose();
    _commissionCtrl.dispose();
    _minimumFareCtrl.dispose();
    _waitingPerMinCtrl.dispose();
    _nightSurchargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final r = await supabase.from('app_settings').select().limit(1).maybeSingle();
      if (r != null) {
        _baseFareCtrl.text = r['base_fare']?.toString() ?? '0';
        _perKmCtrl.text = r['per_km_rate']?.toString() ?? '150';
        _perMinuteCtrl.text = r['per_minute_fare']?.toString() ?? '0';
        _commissionCtrl.text = r['commission_percentage']?.toString() ?? '0';
        _minimumFareCtrl.text = r['minimum_fare']?.toString() ?? '100';
        _waitingPerMinCtrl.text = r['waiting_per_minute']?.toString() ?? '0';
        _nightSurchargeCtrl.text = r['night_surcharge']?.toString() ?? '0';
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingPricing = false);
  }

  Future<void> _savePricing() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingPricing = true);
    try {
      final newPerKm = double.tryParse(_perKmCtrl.text) ?? 150;
      final updates = {
        'id': 1,
        'base_fare': double.tryParse(_baseFareCtrl.text) ?? 0,
        'per_km_rate': newPerKm,
        'per_minute_fare': double.tryParse(_perMinuteCtrl.text) ?? 0,
        'commission_percentage': int.tryParse(_commissionCtrl.text) ?? 0,
        'minimum_fare': double.tryParse(_minimumFareCtrl.text) ?? 100,
        'waiting_per_minute': double.tryParse(_waitingPerMinCtrl.text) ?? 0,
        'night_surcharge': double.tryParse(_nightSurchargeCtrl.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('app_settings').upsert(updates);
      await AdminLogService.log(action: 'Modification tarification', targetType: 'pricing', details: updates);

      // Notifier automatiquement tous les chauffeurs du nouveau tarif
      try {
        await supabase.from('admin_messages').insert({
          'sender_admin_email': supabase.auth.currentUser?.email ?? 'admin',
          'recipient_type': 'all_drivers',
          'recipient_name': 'Tous les chauffeurs',
          'title': 'Mise à jour des tarifs',
          'message': 'Le tarif au kilomètre a été mis à jour à $newPerKm HTG/km. '
              'Tarif de base: ${_baseFareCtrl.text} HTG. '
              'Tarif minimum: ${_minimumFareCtrl.text} HTG. '
              'Cette mise à jour est effective immédiatement.',
        });
      } catch (_) {} // Ne pas bloquer si la notif échoue

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarifs enregistrés et chauffeurs notifiés"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSavingPricing = false);
    }
  }

  void _showDiscountDialog([Map<String, dynamic>? discount]) {
    final isEdit = discount != null;
    final nameCtrl = TextEditingController(text: isEdit ? discount['name']?.toString() : '');
    final valueCtrl = TextEditingController(text: isEdit ? discount['value']?.toString() : '');
    String type = isEdit ? (discount['type'] ?? 'percentage') : 'percentage';
    String appliesTo = isEdit ? (discount['applies_to'] ?? 'all') : 'all';
    bool isActive = isEdit ? (discount['is_active'] ?? true) : true;
    DateTime? startDate = isEdit && discount['start_date'] != null ? DateTime.tryParse(discount['start_date']) : null;
    DateTime? endDate = isEdit && discount['end_date'] != null ? DateTime.tryParse(discount['end_date']) : null;
    final fKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? "Modifier le rabais" : "Créer un rabais", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(key: fKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl, 
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: "Nom du rabais", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)), 
                  validator: (v) => v!.isEmpty ? "Requis" : null
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(labelText: "Type", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                    items: const [
                      DropdownMenuItem(value: 'percentage', child: Text("Pourcentage (%)")),
                      DropdownMenuItem(value: 'fixed', child: Text("Montant fixe (HTG)")),
                    ],
                    onChanged: (v) => setDlg(() => type = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: valueCtrl, 
                    keyboardType: TextInputType.number, 
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(labelText: "Valeur", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54), suffixText: type == 'percentage' ? '%' : 'HTG', suffixStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)), 
                    validator: (v) => v!.isEmpty ? "Requis" : null
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: appliesTo,
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: "S'applique à", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("Tous les utilisateurs")),
                    DropdownMenuItem(value: 'specific_users', child: Text("Utilisateurs spécifiques")),
                    DropdownMenuItem(value: 'zone', child: Text("Zone géographique")),
                  ],
                  onChanged: (v) => setDlg(() => appliesTo = v!),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Début", style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(startDate != null ? "${startDate!.day}/${startDate!.month}/${startDate!.year}" : "Non défini", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.black87)),
                    trailing: IconButton(icon: const Icon(Icons.calendar_today, size: 18), onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                      if (d != null) setDlg(() => startDate = d);
                    }),
                  )),
                  Expanded(child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Fin", style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(endDate != null ? "${endDate!.day}/${endDate!.month}/${endDate!.year}" : "Non défini", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.black87)),
                    trailing: IconButton(icon: const Icon(Icons.calendar_today, size: 18), onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: endDate ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                      if (d != null) setDlg(() => endDate = d);
                    }),
                  )),
                ]),
                SwitchListTile(title: Text("Actif", style: TextStyle(color: isDark ? Colors.white : Colors.black87)), value: isActive, onChanged: (v) => setDlg(() => isActive = v)),
              ])),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                if (!fKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final data = {
                  'name': nameCtrl.text,
                  'type': type,
                  'value': double.tryParse(valueCtrl.text) ?? 0,
                  'applies_to': appliesTo,
                  'is_active': isActive,
                  'start_date': startDate?.toIso8601String(),
                  'end_date': endDate?.toIso8601String(),
                };
                try {
                  if (isEdit) {
                    await supabase.from('discounts').update(data).eq('id', discount['id']);
                  } else {
                    await supabase.from('discounts').insert(data);
                  }
                  await AdminLogService.log(action: isEdit ? 'Modification rabais' : 'Création rabais', targetType: 'discount', details: data);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Rabais modifié" : "Rabais créé"), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              child: const Text("Sauvegarder"),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Tarification & Rabais", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Gérer les tarifs et les promotions", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 24),
          TabBar(controller: _tabController, labelColor: const Color(0xFF6366F1), unselectedLabelColor: Colors.grey.shade500, indicatorColor: const Color(0xFF6366F1), tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: "Tarification"),
            Tab(icon: Icon(Icons.discount), text: "Rabais"),
          ]),
          const SizedBox(height: 16),
          Expanded(child: TabBarView(controller: _tabController, children: [_pricingTab(isDark), _discountsTab(isDark)])),
        ]),
      ),
    );
  }

  Widget _pricingTab(bool isDark) {
    if (_isLoadingPricing) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Form(key: _formKey, child: Card(
        elevation: 0, color: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          _pField("Tarif de base / Prise en charge (HTG)", _baseFareCtrl, Icons.money, isDark),
          const SizedBox(height: 16),
          _pField("Tarif au kilomètre (HTG)", _perKmCtrl, Icons.add_road, isDark),
          const SizedBox(height: 16),
          _pField("Tarif à la minute (HTG)", _perMinuteCtrl, Icons.timer, isDark),
          const SizedBox(height: 16),
          _pField("Commission (%)", _commissionCtrl, Icons.percent, isDark),
          const SizedBox(height: 16),
          _pField("Tarif minimum (HTG)", _minimumFareCtrl, Icons.low_priority, isDark),
          const SizedBox(height: 16),
          _pField("Attente par minute (HTG)", _waitingPerMinCtrl, Icons.hourglass_empty, isDark),
          const SizedBox(height: 16),
          _pField("Majoration nuit (HTG)", _nightSurchargeCtrl, Icons.nightlight_round, isDark),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: _isSavingPricing ? null : _savePricing,
            icon: _isSavingPricing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_isSavingPricing ? "Enregistrement..." : "Enregistrer les tarifs"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
          )),
        ])),
      )),
    );
  }

  Widget _pField(String label, TextEditingController ctrl, IconData icon, bool isDark) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
      ),
      validator: (v) => v == null || v.isEmpty ? "Requis" : double.tryParse(v) == null ? "Nombre invalide" : null,
    );
  }

  Widget _discountsTab(bool isDark) {
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: () => _showDiscountDialog(),
          icon: const Icon(Icons.add),
          label: const Text("Nouveau rabais"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('discounts').stream(primaryKey: ['id']).order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final discounts = snapshot.data!;
            if (discounts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.discount_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text("Aucun rabais créé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            ]));
            return ListView.builder(itemCount: discounts.length, itemBuilder: (ctx, i) {
              final d = discounts[i];
              final isActive = d['is_active'] ?? false;
              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? const Color(0xFF10B981).withOpacity(0.1) : Colors.grey.shade200,
                    child: Icon(d['type'] == 'percentage' ? Icons.percent : Icons.attach_money, color: isActive ? const Color(0xFF10B981) : Colors.grey, size: 20),
                  ),
                  title: Text(d['name']?.toString() ?? 'Sans nom', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text("${d['value']}${d['type'] == 'percentage' ? '%' : ' HTG'} • ${d['applies_to'] == 'all' ? 'Tous' : d['applies_to']}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: isActive, onChanged: (v) async {
                      await supabase.from('discounts').update({'is_active': v}).eq('id', d['id']);
                      await AdminLogService.log(action: v ? 'Activation rabais' : 'Désactivation rabais', targetType: 'discount', targetId: d['id']?.toString());
                    }, activeColor: const Color(0xFF10B981)),
                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showDiscountDialog(d)),
                    IconButton(icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400), onPressed: () async {
                      final ok = await showDialog<bool>(context: context, builder: (c) {
                        final dkDlg = Theme.of(context).brightness == Brightness.dark;
                        return AlertDialog(
                          backgroundColor: dkDlg ? AppColors.darkCard : Colors.white,
                          title: Text("Supprimer le rabais ?", style: TextStyle(color: dkDlg ? Colors.white : Colors.black87)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Annuler")),
                            ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Supprimer", style: TextStyle(color: Colors.white))),
                          ],
                        );
                      });
                      if (ok == true) {
                        await supabase.from('discounts').delete().eq('id', d['id']);
                        await AdminLogService.log(action: 'Suppression rabais', targetType: 'discount', targetId: d['id']?.toString());
                      }
                    }),
                  ]),
                ),
              );
            });
          },
        ),
      ),
    ]);
  }
}
