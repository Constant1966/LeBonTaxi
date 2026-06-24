// lib/pages/driver_documents_page.dart  (admin_lebontaxi_web_panel)
// VERSION MISE À JOUR — badge "Changement de véhicule" + emails
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../services/admin_log_service.dart';
import '../services/fcm_notification_service.dart';
import '../services/email_service.dart';
import '../methods/common_methods.dart';
import '../widgets/document_review_card.dart';

class DriverDocumentsPage extends StatefulWidget {
  static const String id = "\\webPageDriverDocuments";
  const DriverDocumentsPage({super.key});

  @override
  State<DriverDocumentsPage> createState() => _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends State<DriverDocumentsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _commonMethods = CommonMethods();

  late TabController _tabController;

  List<Map<String, dynamic>> _pendingDrivers  = [];
  List<Map<String, dynamic>> _approvedDrivers = [];
  List<Map<String, dynamic>> _rejectedDrivers = [];

  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  int get _totalPending  => _pendingDrivers.length;
  int get _totalApproved => _approvedDrivers.length;
  int get _totalRejected => _rejectedDrivers.length;

  // Compteur de changements de véhicule en attente
  int get _vehicleChangePending =>
      _pendingDrivers.where((d) => d['vehicle_change_pending'] == true).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDriversByDocumentStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadDriversByDocumentStatus() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('drivers')
          .select(
            'id, name, email, phone, photo, document_status, '
            'documents_rejection_note, profile_completed, verified, '
            'vehicle_change_pending, previous_vehicle_info, '
            'car_model, car_color, car_number, car_year, car_front_photo, '
            'created_at',
          )
          .eq('profile_completed', true)
          .order('created_at', ascending: false);

      final drivers = List<Map<String, dynamic>>.from(data);

      setState(() {
        _pendingDrivers = drivers
            .where((d) =>
                d['document_status'] == 'pending' ||
                d['document_status'] == 'under_review')
            .toList();
        _approvedDrivers =
            drivers.where((d) => d['document_status'] == 'approved').toList();
        _rejectedDrivers =
            drivers.where((d) => d['document_status'] == 'rejected').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _commonMethods.showSnackBar(context, 'Erreur chargement: $e', isError: true);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            _buildHeader(isDark),
            const SizedBox(height: 20),
            _buildStatsRow(isDark),
            const SizedBox(height: 20),
            _buildSearchBar(isDark),
            const SizedBox(height: 16),
            _buildTabBar(isDark),
            const SizedBox(height: 16),
            Expanded(child: _buildTabViews(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vérification des Documents',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Approuver ou rejeter les documents des chauffeurs',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            // Badge changements de véhicule
            if (_vehicleChangePending > 0)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.indigo.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 16, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Text(
                      '$_vehicleChangePending changement(s) véhicule',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo),
                    ),
                  ],
                ),
              ),
            IconButton(
              onPressed: _loadDriversByDocumentStatus,
              icon: const Icon(Icons.refresh),
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _statCard('En attente', _totalPending, Colors.orange,
            Icons.hourglass_top, isDark),
        const SizedBox(width: 16),
        _statCard('Approuvés', _totalApproved, Colors.green,
            Icons.verified, isDark),
        const SizedBox(width: 16),
        _statCard(
            'Rejetés', _totalRejected, Colors.red, Icons.cancel, isDark),
      ],
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon,
      bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : Colors.grey.shade200),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count.toString(),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou email...',
                hintStyle: TextStyle(
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF6B7280)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0, vertical: 15),
              ),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
              onSubmitted: (v) {
                setState(() => _searchQuery = v.toLowerCase());
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6366F1),
        unselectedLabelColor:
            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        indicatorColor: const Color(0xFF6366F1),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top, size: 16),
              const SizedBox(width: 6),
              Text('En attente ($_totalPending)'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified, size: 16),
              const SizedBox(width: 6),
              Text('Approuvés ($_totalApproved)'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cancel, size: 16),
              const SizedBox(width: 6),
              Text('Rejetés ($_totalRejected)'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabViews(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDriverList(_filteredList(_pendingDrivers), isDark),
        _buildDriverList(_filteredList(_approvedDrivers), isDark),
        _buildDriverList(_filteredList(_rejectedDrivers), isDark),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredList(
      List<Map<String, dynamic>> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((d) {
      final name  = d['name']?.toString().toLowerCase()  ?? '';
      final email = d['email']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  Widget _buildDriverList(
      List<Map<String, dynamic>> drivers, bool isDark) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Aucun résultat trouvé'
                  : 'Aucun chauffeur dans cette catégorie',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDriversByDocumentStatus,
      child: ListView.builder(
        itemCount: drivers.length,
        itemBuilder: (_, i) => DriverDocumentSummaryCard(
          driver: drivers[i],
          isDark: isDark,
          onOpenReview: () =>
              _openDocumentReviewDialog(drivers[i], isDark),
          onQuickApprove: () => _approveAllDocuments(drivers[i]),
          onQuickReject: () =>
              _showRejectAllDialog(drivers[i], isDark),
        ),
      ),
    );
  }

  // ── Document review dialog ────────────────────────────────────────────────

  void _openDocumentReviewDialog(
      Map<String, dynamic> driver, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentReviewDialog(
        driver: driver,
        isDark: isDark,
        onStatusChanged: _loadDriversByDocumentStatus,
      ),
    );
  }

  // ── Quick approve all ─────────────────────────────────────────────────────

  Future<void> _approveAllDocuments(Map<String, dynamic> driver) async {
    final driverId   = driver['id']?.toString() ?? '';
    final driverName = driver['name']?.toString() ?? 'Chauffeur';
    final isVehicleChange = driver['vehicle_change_pending'] == true;

    final confirmed = await _confirm(
      'Approuver tous les documents',
      'Approuver tous les documents de $driverName et activer son compte ?',
    );
    if (!confirmed) return;

    try {
      await supabase
          .from('driver_documents')
          .update({
            'status': 'approved',
            'reviewed_by': supabase.auth.currentUser?.email ?? 'admin',
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      await supabase.from('drivers').update({
        'document_status': 'approved',
        'verified': true,
        'vehicle_change_pending': false,
      }).eq('id', driverId);

      // Push FCM + Email
      await FcmNotificationService.sendToDriver(
        driverId: driverId,
        type: 'document_status_changed',
        title: isVehicleChange
            ? '🎉 Nouveau véhicule approuvé !'
            : '🎉 Compte activé !',
        body: isVehicleChange
            ? 'Les documents de votre nouveau véhicule ont été approuvés. Vous pouvez de nouveau accepter des courses.'
            : 'Tous vos documents ont été approuvés. Vous pouvez maintenant accepter des courses.',
        data: {'document_status': 'approved'},
        sendEmail: true,
        isVehicleChange: isVehicleChange,
      );

      await AdminLogService.log(
        action: isVehicleChange
            ? 'Approbation changement véhicule'
            : 'Approbation totale documents',
        targetType: 'driver',
        targetId: driverId,
        details: {
          'driver_name': driverName,
          'vehicle_change': isVehicleChange,
        },
      );

      if (mounted) {
        _commonMethods.showSnackBar(context, '$driverName — compte activé');
        _loadDriversByDocumentStatus();
      }
    } catch (e) {
      if (mounted) {
        _commonMethods.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    }
  }

  // ── Quick reject all ──────────────────────────────────────────────────────

  void _showRejectAllDialog(
      Map<String, dynamic> driver, bool isDark) {
    final reasonCtrl = TextEditingController();
    final isVehicleChange = driver['vehicle_change_pending'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.cancel, color: Colors.red),
          const SizedBox(width: 10),
          Text(
              isVehicleChange
                  ? 'Rejeter le changement de véhicule'
                  : 'Rejeter le dossier',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87)),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chauffeur : ${driver['name'] ?? 'N/A'}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white70 : Colors.black87)),
              if (isVehicleChange) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.indigo.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          size: 16, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('Changement de véhicule',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(
                    color:
                        isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText:
                      'Raison du rejet (visible par le chauffeur)',
                  labelStyle: TextStyle(
                      color:
                          isDark ? Colors.white70 : Colors.black54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _rejectAllDocuments(
                  driver, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectAllDocuments(
      Map<String, dynamic> driver, String reason) async {
    final driverId   = driver['id']?.toString() ?? '';
    final driverName = driver['name']?.toString() ?? 'Chauffeur';
    final isVehicleChange = driver['vehicle_change_pending'] == true;

    try {
      await supabase
          .from('driver_documents')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'reviewed_by': supabase.auth.currentUser?.email ?? 'admin',
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('driver_id', driverId)
          .eq('status', 'pending');

      await supabase.from('drivers').update({
        'document_status': 'rejected',
        'documents_rejection_note': reason,
        'verified': false,
      }).eq('id', driverId);

      // Push FCM + Email
      await FcmNotificationService.sendToDriver(
        driverId: driverId,
        type: 'document_status_changed',
        title: '❌ Dossier rejeté',
        body: reason,
        data: {
          'document_status': 'rejected',
          'rejection_reason': reason,
        },
        sendEmail: true,
        rejectionReason: reason,
        isVehicleChange: isVehicleChange,
      );

      await AdminLogService.log(
        action: isVehicleChange
            ? 'Rejet changement véhicule'
            : 'Rejet total documents',
        targetType: 'driver',
        targetId: driverId,
        details: {
          'driver_name': driverName,
          'reason': reason,
          'vehicle_change': isVehicleChange,
        },
      );

      if (mounted) {
        _commonMethods.showSnackBar(context, '$driverName — dossier rejeté', isError: true);
        _loadDriversByDocumentStatus();
      }
    } catch (e) {
      if (mounted) {
        _commonMethods.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text(title,
                style: TextStyle(
                    color:
                        isDark ? Colors.white : Colors.black87)),
            content: Text(message,
                style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : Colors.black87)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
