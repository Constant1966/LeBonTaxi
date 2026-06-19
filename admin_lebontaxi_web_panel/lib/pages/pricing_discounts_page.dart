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

  // Referral settings
  bool _referralEnabled = true;
  String _referralRewardType = 'percentage';
  final _referralValueCtrl = TextEditingController();
  final _referralShareMsgCtrl = TextEditingController();
  bool _isSavingReferral = false;

  // Welcome settings
  bool _welcomeEnabled = true;
  String _welcomeRewardType = 'percentage';
  final _welcomeValueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _referralValueCtrl.dispose();
    _referralShareMsgCtrl.dispose();
    _welcomeValueCtrl.dispose();
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
        
        // Referral settings
        _referralEnabled = r['referral_reward_enabled'] ?? true;
        _referralRewardType = r['referral_reward_type']?.toString() ?? 'percentage';
        _referralValueCtrl.text = r['referral_reward_value']?.toString() ?? '10';
        _referralShareMsgCtrl.text = r['referral_share_message']?.toString() ??
            "Rejoins-moi sur LeBonTaxi ! Télécharge l'application et utilise mon code promo {code} lors de ton inscription pour obtenir des réductions.";
        
        // Welcome settings with fallback
        try {
          _welcomeEnabled = r['referral_welcome_enabled'] ?? true;
          _welcomeRewardType = r['referral_welcome_type']?.toString() ?? 'percentage';
          _welcomeValueCtrl.text = r['referral_welcome_value']?.toString() ?? '5';
        } catch (_) {
          _welcomeEnabled = true;
          _welcomeRewardType = 'percentage';
          _welcomeValueCtrl.text = '5';
        }
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "Tarification & Promotions", 
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )
          ),
          const SizedBox(height: 8),
          Text(
            "Gérez les tarifs de base, les codes promo et le programme de parrainage.", 
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            )
          ),
          const SizedBox(height: 32),
          
          // Modern Segmented TabBar
          Container(
            height: 52,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162240) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController, 
              labelColor: isDark ? Colors.white : AppColors.primary, 
              unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600, 
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.attach_money_rounded, size: 18), SizedBox(width: 8), Text("Tarifs Standards", style: TextStyle(fontWeight: FontWeight.w600))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.discount_rounded, size: 18), SizedBox(width: 8), Text("Codes Promo", style: TextStyle(fontWeight: FontWeight.w600))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.card_giftcard_rounded, size: 18), SizedBox(width: 8), Text("Parrainage", style: TextStyle(fontWeight: FontWeight.w600))])),
              ]
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: TabBarView(controller: _tabController, children: [_pricingTab(isDark), _discountsTab(isDark), _referralTab(isDark)])),
        ]),
      ),
    );
  }

  Widget _pricingTab(bool isDark) {
    if (_isLoadingPricing) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Form(
        key: _formKey, 
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = constraints.maxWidth > 1000 
                ? (constraints.maxWidth - 32) / 2 
                : constraints.maxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 22)),
                            const SizedBox(width: 16),
                            const Text("Tarification Trajet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ]),
                          const SizedBox(height: 28),
                          _pField("Prise en charge (Base HTG)", _baseFareCtrl, Icons.flag_rounded),
                          const SizedBox(height: 20),
                          _pField("Tarif au kilomètre (HTG)", _perKmCtrl, Icons.add_road_rounded),
                          const SizedBox(height: 20),
                          _pField("Tarif minimum garanti (HTG)", _minimumFareCtrl, Icons.verified_user_rounded),
                        ]),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 22)),
                            const SizedBox(width: 16),
                            const Text("Temps & Suppléments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ]),
                          const SizedBox(height: 28),
                          _pField("Attente par minute (HTG)", _waitingPerMinCtrl, Icons.hourglass_bottom_rounded),
                          const SizedBox(height: 20),
                          _pField("Tarif à la minute de conduite (HTG)", _perMinuteCtrl, Icons.timer_outlined),
                          const SizedBox(height: 20),
                          _pField("Majoration nuit (HTG)", _nightSurchargeCtrl, Icons.nights_stay_rounded),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, 
                  height: 54, 
                  child: ElevatedButton.icon(
                    onPressed: _isSavingPricing ? null : _savePricing,
                    icon: _isSavingPricing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
                    label: Text(_isSavingPricing ? "Enregistrement..." : "Appliquer et notifier les chauffeurs"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                  )
                ),
                const SizedBox(height: 40),
              ],
            );
          }
        )
      ),
    );
  }

  Widget _pField(String label, TextEditingController ctrl, IconData icon) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon, size: 20), 
      ),
      validator: (v) => v == null || v.isEmpty ? "Requis" : double.tryParse(v) == null ? "Nombre invalide" : null,
    );
  }

  Widget _discountsTab(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Codes Promotionnels Actifs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ElevatedButton.icon(
          onPressed: () => _showDiscountDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text("Créer un code"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
        ),
      ]),
      const SizedBox(height: 24),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('discounts').stream(primaryKey: ['id']).order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final discounts = snapshot.data!;
            if (discounts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.discount_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("Aucun code promo créé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
            ]));
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 2.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: discounts.length, 
              itemBuilder: (ctx, i) {
                final d = discounts[i];
                final isActive = d['is_active'] ?? false;
                final isPercentage = d['type'] == 'percentage';
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isActive ? AppColors.primary.withOpacity(0.5) : (isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Stack(
                    children: [
                      // Left color accent
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : Colors.grey.shade400,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                          ),
                        )
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 12, top: 12, bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(d['name']?.toString() ?? 'PROMO', style: TextStyle(fontWeight: FontWeight.w900, color: isActive ? AppColors.primary : Colors.grey, letterSpacing: 1)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text("${d['value']}${isPercentage ? '%' : ' HTG'} de réduction", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text("Cible: ${d['applies_to'] == 'all' ? 'Tous les clients' : d['applies_to']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _showDiscountDialog(d), constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                                    IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade400), onPressed: () async {
                                      final ok = await showDialog<bool>(context: context, builder: (c) {
                                        return AlertDialog(
                                          title: const Text("Supprimer le rabais ?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Annuler")),
                                            ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Supprimer", style: TextStyle(color: Colors.white))),
                                          ],
                                        );
                                      });
                                      if (ok == true) await supabase.from('discounts').delete().eq('id', d['id']);
                                    }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                                  ],
                                ),
                                Switch(value: isActive, onChanged: (v) async {
                                  await supabase.from('discounts').update({'is_active': v}).eq('id', d['id']);
                                }, activeColor: AppColors.primary),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                );
              }
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _saveReferralSettings() async {
    setState(() => _isSavingReferral = true);
    try {
      final updates = {
        'id': 1,
        'referral_reward_enabled': _referralEnabled,
        'referral_reward_type': _referralRewardType,
        'referral_reward_value': double.tryParse(_referralValueCtrl.text) ?? 10.0,
        'referral_share_message': _referralShareMsgCtrl.text.trim(),
        'referral_welcome_enabled': _welcomeEnabled,
        'referral_welcome_type': _welcomeRewardType,
        'referral_welcome_value': double.tryParse(_welcomeValueCtrl.text) ?? 5.0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      try {
        await supabase.from('app_settings').upsert(updates);
      } catch (dbError) {
        print("⚠️ Colonnes de bienvenue manquantes sur app_settings, fallback sans elles: $dbError");
        final fallbackUpdates = {
          'id': 1,
          'referral_reward_enabled': _referralEnabled,
          'referral_reward_type': _referralRewardType,
          'referral_reward_value': double.tryParse(_referralValueCtrl.text) ?? 10.0,
          'referral_share_message': _referralShareMsgCtrl.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await supabase.from('app_settings').upsert(fallbackUpdates);
      }

      await AdminLogService.log(action: 'Modification parrainage', targetType: 'settings', targetId: '1', details: updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Configuration du parrainage enregistrée avec succès !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingReferral = false);
    }
  }

  Widget _referralTab(bool isDark) {
    if (_isLoadingPricing) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final formPanel = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 22)),
                  const SizedBox(width: 16),
                  const Text("Offre Parrain", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text("Activer le programme de parrainage", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Permet de gagner des réductions"),
                  value: _referralEnabled,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _referralEnabled = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _referralRewardType,
                  decoration: const InputDecoration(labelText: "Type de récompense", prefixIcon: Icon(Icons.card_giftcard_rounded, size: 20)),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text("Pourcentage (%)")),
                    DropdownMenuItem(value: 'fixed', child: Text("Montant fixe (HTG)")),
                  ],
                  onChanged: (v) => setState(() => _referralRewardType = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralValueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Valeur",
                    prefixIcon: const Icon(Icons.monetization_on_rounded, size: 20),
                    suffixText: _referralRewardType == 'percentage' ? '%' : 'HTG',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralShareMsgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Message de partage",
                    helperText: "Utilisez {code} pour insérer automatiquement le code unique du parrain.",
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.stars_rounded, color: Colors.purple, size: 22)),
                  const SizedBox(width: 16),
                  const Text("Offre Filleul (Bienvenue)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text("Activer la récompense filleul", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Réduction accordée à l'inscription"),
                  value: _welcomeEnabled,
                  activeColor: Colors.purple,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _welcomeEnabled = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _welcomeRewardType,
                  decoration: const InputDecoration(labelText: "Type de récompense", prefixIcon: Icon(Icons.card_giftcard_rounded, size: 20)),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text("Pourcentage (%)")),
                    DropdownMenuItem(value: 'fixed', child: Text("Montant fixe (HTG)")),
                  ],
                  onChanged: (v) => setState(() => _welcomeRewardType = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _welcomeValueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Valeur de la réduction",
                    prefixIcon: const Icon(Icons.monetization_on_rounded, size: 20),
                    suffixText: _welcomeRewardType == 'percentage' ? '%' : 'HTG',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSavingReferral ? null : _saveReferralSettings,
              icon: _isSavingReferral
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: const Text("Enregistrer la configuration"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      );

      final logPanel = Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Historique des Parrainages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('referral_rewards').stream(primaryKey: ['id']).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rewards = snapshot.data!;
                  if (rewards.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text("Aucun parrainage enregistré", style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: rewards.length,
                    itemBuilder: (ctx, i) {
                      final r = rewards[i];
                      final isUsed = r['status'] == 'used';
                      final val = r['reward_value'];
                      final type = r['reward_type'] == 'percentage' ? '%' : ' HTG';
                      final isWelcome = r.containsKey('is_welcome') && r['is_welcome'] == true;

                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchUserDetails(r['referrer_id']?.toString(), r['referred_id']?.toString()),
                        builder: (context, userSnapshot) {
                          String referrerName = "Chargement...";
                          String referredName = "Chargement...";
                          
                          if (userSnapshot.hasData && userSnapshot.data!.length == 2) {
                            referrerName = userSnapshot.data![0]['name']?.toString() ?? 'Inconnu';
                            referredName = userSnapshot.data![1]['name']?.toString() ?? 'Inconnu';
                          } else if (userSnapshot.hasError) {
                            referrerName = "Erreur";
                            referredName = "Erreur";
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isUsed 
                                      ? Colors.grey.withOpacity(0.2) 
                                      : (isWelcome ? Colors.purple.withOpacity(0.1) : AppColors.primary.withOpacity(0.1)),
                                  child: Icon(
                                    isWelcome ? Icons.card_giftcard : Icons.group_add_rounded,
                                    color: isUsed ? Colors.grey : (isWelcome ? Colors.purple : AppColors.primary), 
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                                          children: [
                                            TextSpan(text: referrerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            TextSpan(text: isWelcome ? " a obtenu son gain de bienvenue (par " : " a parrainé "),
                                            TextSpan(text: referredName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            if (isWelcome) const TextSpan(text: ")"),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Gain: -$val$type",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isUsed ? Colors.grey.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isUsed ? "Utilisé" : "Disponible",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUsed ? Colors.grey.shade600 : Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );

      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: formPanel),
            const SizedBox(width: 32),
            Expanded(flex: 5, child: SizedBox(height: 800, child: logPanel)),
          ],
        );
      } else {
        return Column(
          children: [
            formPanel,
            const SizedBox(height: 32),
            SizedBox(height: 600, child: logPanel),
          ],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUserDetails(String? referrerId, String? referredId) async {
    try {
      if (referrerId == null || referredId == null) return [];
      
      final refProfile = await supabase.from('users').select('name').eq('id', referrerId).maybeSingle();
      final refrdProfile = await supabase.from('users').select('name').eq('id', referredId).maybeSingle();
      
      return [
        {'name': refProfile?['name']?.toString() ?? 'Utilisateur ID $referrerId'},
        {'name': refrdProfile?['name']?.toString() ?? 'Utilisateur ID $referredId'}
      ];
    } catch (_) {
      return [
        {'name': 'Utilisateur ID $referrerId'},
        {'name': 'Utilisateur ID $referredId'}
      ];
    }
  }
}
