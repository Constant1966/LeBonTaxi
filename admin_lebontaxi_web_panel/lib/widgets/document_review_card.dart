// lib/widgets/document_review_card.dart
//
// Deux widgets :
//   1. DriverDocumentSummaryCard — ligne dans la liste principale
//   2. DocumentReviewDialog     — dialog de revue document par document
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../services/admin_log_service.dart';
import '../services/fcm_notification_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. DriverDocumentSummaryCard
// ═════════════════════════════════════════════════════════════════════════════

class DriverDocumentSummaryCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final bool isDark;
  final VoidCallback onOpenReview;
  final VoidCallback onQuickApprove;
  final VoidCallback onQuickReject;

  const DriverDocumentSummaryCard({
    super.key,
    required this.driver,
    required this.isDark,
    required this.onOpenReview,
    required this.onQuickApprove,
    required this.onQuickReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = driver['document_status']?.toString() ?? 'pending';
    final name = driver['name']?.toString() ?? 'N/A';
    final email = driver['email']?.toString() ?? '';
    final createdAt = driver['created_at']?.toString().substring(0, 10) ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(name),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _statusBadge(status),
                    const SizedBox(width: 8),
                    // Document count badge (async)
                    _DocumentCountBadge(
                        driverId: driver['id']?.toString() ?? '',
                        isDark: isDark),
                  ]),
                ],
              ),
            ),

            // Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Inscrit le',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500)),
                Text(createdAt,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700)),
              ],
            ),

            const SizedBox(width: 12),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(
                  icon: Icons.visibility,
                  label: 'Réviser',
                  color: const Color(0xFF6366F1),
                  onTap: onOpenReview,
                ),
                if (status == 'pending' || status == 'under_review') ...[
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.check_circle,
                    label: 'Approuver tout',
                    color: Colors.green,
                    onTap: onQuickApprove,
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.cancel,
                    label: 'Rejeter',
                    color: Colors.red,
                    onTap: onQuickReject,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final photoUrl = driver['photo']?.toString() ?? '';
    if (photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          photoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initAvatar(name),
        ),
      );
    }
    return _initAvatar(name);
  }

  Widget _initAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Map<String, _BadgeStyle> styles = {
      'pending': _BadgeStyle(Colors.orange, 'En attente'),
      'under_review': _BadgeStyle(Colors.blue, 'En révision'),
      'approved': _BadgeStyle(Colors.green, 'Approuvé'),
      'rejected': _BadgeStyle(Colors.red, 'Rejeté'),
      'documents_required': _BadgeStyle(Colors.deepOrange, 'Docs manquants'),
    };
    final s = styles[status] ?? _BadgeStyle(Colors.grey, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withOpacity(0.3)),
      ),
      child: Text(s.label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: s.color)),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _BadgeStyle {
  final Color color;
  final String label;
  const _BadgeStyle(this.color, this.label);
}

// Small widget showing pending / approved / rejected document counts
class _DocumentCountBadge extends StatelessWidget {
  final String driverId;
  final bool isDark;
  const _DocumentCountBadge({required this.driverId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('driver_documents')
          .select('status')
          .eq('driver_id', driverId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5));
        }
        final docs = snap.data!;
        final pending = docs.where((d) => d['status'] == 'pending').length;
        final approved = docs.where((d) => d['status'] == 'approved').length;
        final rejected = docs.where((d) => d['status'] == 'rejected').length;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _pill('$approved ✓', Colors.green),
          const SizedBox(width: 4),
          if (pending > 0) _pill('$pending ⏳', Colors.orange),
          if (pending > 0) const SizedBox(width: 4),
          if (rejected > 0) _pill('$rejected ✗', Colors.red),
        ]);
      },
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. DocumentReviewDialog
// ═════════════════════════════════════════════════════════════════════════════

class DocumentReviewDialog extends StatefulWidget {
  final Map<String, dynamic> driver;
  final bool isDark;
  final VoidCallback onStatusChanged;

  const DocumentReviewDialog({
    super.key,
    required this.driver,
    required this.isDark,
    required this.onStatusChanged,
  });

  @override
  State<DocumentReviewDialog> createState() => _DocumentReviewDialogState();
}

class _DocumentReviewDialogState extends State<DocumentReviewDialog> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  String get _driverId =>
      widget.driver['id']?.toString() ?? '';
  String get _driverName => widget.driver['name']?.toString() ?? 'Chauffeur';

  static const Map<String, String> _docLabels = {
    'drivers_license': 'Permis de conduire',
    'criminal_record': 'Casier judiciaire',
    'identity_card': 'Carte d\'identité (CIN)',
    'vehicle_registration': 'Carte grise',
    'vehicle_insurance': 'Assurance véhicule',
    'tdc_permit': 'Permis TDC',
    'technical_inspection': 'Visite technique',
    'other': 'Autre document',
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', _driverId)
          .order('submitted_at', ascending: true);
      setState(() {
        _documents = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ── Approve single doc ─────────────────────────────────────────────────────

  Future<void> _approveDocument(Map<String, dynamic> doc) async {
    try {
      await supabase.from('driver_documents').update({
        'status': 'approved',
        'rejection_reason': null,
        'reviewed_by': supabase.auth.currentUser?.email ?? 'admin',
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', doc['id']);

      await _updateDriverDocumentStatus();

      // FCM
      await FcmNotificationService.sendToDriver(
        driverId: _driverId,
        type: 'document_approved',
        title: '✅ Document approuvé',
        body: '${_labelFor(doc['document_type'])} a été approuvé.',
        data: {
          'type': 'document_approved',
          'document_id': doc['id']?.toString() ?? '',
          'document_type': doc['document_type']?.toString() ?? '',
          'document_label': _labelFor(doc['document_type']),
        },
      );

      await AdminLogService.log(
        action: 'Approbation document',
        targetType: 'driver',
        targetId: _driverId,
        details: {
          'driver': _driverName,
          'document_type': doc['document_type'],
          'document_id': doc['id'],
        },
      );

      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document approuvé'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Reject single doc ──────────────────────────────────────────────────────

  void _showRejectDocumentDialog(Map<String, dynamic> doc) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rejeter : ${_labelFor(doc['document_type'])}',
            style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 15)),
        content: SizedBox(
          width: 400,
          child: TextFormField(
            controller: reasonCtrl,
            maxLines: 3,
            autofocus: true,
            style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Motif du rejet (visible par le chauffeur)',
              labelStyle: TextStyle(
                  color: widget.isDark ? Colors.white70 : Colors.black54),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
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
              await _rejectDocument(doc, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDocument(
      Map<String, dynamic> doc, String reason) async {
    try {
      await supabase.from('driver_documents').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_by': supabase.auth.currentUser?.email ?? 'admin',
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', doc['id']);

      await _updateDriverDocumentStatus();

      await FcmNotificationService.sendToDriver(
        driverId: _driverId,
        type: 'document_rejected',
        title: '❌ Document rejeté',
        body: reason,
        data: {
          'type': 'document_rejected',
          'document_id': doc['id']?.toString() ?? '',
          'document_type': doc['document_type']?.toString() ?? '',
          'document_label': _labelFor(doc['document_type']),
          'rejection_reason': reason,
        },
      );

      await AdminLogService.log(
        action: 'Rejet document',
        targetType: 'driver',
        targetId: _driverId,
        details: {
          'driver': _driverName,
          'document_type': doc['document_type'],
          'reason': reason,
        },
      );

      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document rejeté'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Update driver's global document_status ─────────────────────────────────

  Future<void> _updateDriverDocumentStatus() async {
    final docs = await supabase
        .from('driver_documents')
        .select('status, document_type')
        .eq('driver_id', _driverId);

    final all = List<Map<String, dynamic>>.from(docs);
    final hasRejected = all.any((d) => d['status'] == 'rejected');
    final hasPending  = all.any((d) => d['status'] == 'pending');

    const required = [
      'drivers_license',
      'criminal_record',
      'identity_card',
      'vehicle_registration',
      'vehicle_insurance',
    ];

    final approvedTypes = all
        .where((d) => d['status'] == 'approved')
        .map((d) => d['document_type'])
        .toSet();
    final allRequiredApproved =
    required.every((t) => approvedTypes.contains(t));

    String newStatus;
    bool verified = false;

    if (hasRejected) {
      newStatus = 'rejected';
    } else if (allRequiredApproved) {
      newStatus = 'approved';
      verified  = true;
    } else if (hasPending) {
      newStatus = 'under_review';
    } else {
      newStatus = 'documents_required';
    }

    await supabase.from('drivers').update({
      'document_status': newStatus,
      if (verified) 'verified': true,
      if (verified) 'vehicle_change_pending': false,
    }).eq('id', _driverId);

    // ✅ Email envoyé UNIQUEMENT quand tous les documents obligatoires
    //    viennent d'être approuvés (passage à 'approved')
    if (verified) {
      try {
        // Récupérer email + nom du chauffeur
        final driverRow = await supabase
            .from('drivers')
            .select('email, name, vehicle_change_pending')
            .eq('id', _driverId)
            .maybeSingle();

        final email = driverRow?['email']?.toString() ?? '';
        final name  = driverRow?['name']?.toString()  ?? 'Chauffeur';
        final isVehicleChange =
            widget.driver['vehicle_change_pending'] == true;

        if (email.isNotEmpty) {
          await FcmNotificationService.sendToDriver(
            driverId: _driverId,
            type: 'document_status_changed',
            title: isVehicleChange
                ? '🎉 Nouveau véhicule approuvé !'
                : '🎉 Compte activé !',
            body: isVehicleChange
                ? 'Les documents de votre nouveau véhicule ont été approuvés.'
                : 'Tous vos documents ont été approuvés. Vous pouvez recevoir des courses.',
            data: {'document_status': 'approved'},
            sendEmail: true,
            driverEmail: email,
            driverName: name,
            isVehicleChange: isVehicleChange,
          );
        }
      } catch (emailErr) {
        print('[Email] Erreur envoi approbation: $emailErr');
      }
    }

    widget.onStatusChanged();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 780),
        child: Column(
          children: [
            _buildDialogHeader(isDark),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                  ? _buildEmptyState()
                  : _buildDocumentGrid(isDark),
            ),
            _buildDialogFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
            bottom: BorderSide(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Driver avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _driverName.isNotEmpty ? _driverName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_driverName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(widget.driver['email']?.toString() ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600)),
              ],
            ),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Rafraîchir',
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 340,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _documents.length,
      itemBuilder: (_, i) =>
          _DocumentReviewCard(
            doc: _documents[i],
            isDark: isDark,
            onApprove: () => _approveDocument(_documents[i]),
            onReject: () => _showRejectDocumentDialog(_documents[i]),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Aucun document soumis',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(bool isDark) {
    // Summary stats
    final approved = _documents.where((d) => d['status'] == 'approved').length;
    final pending = _documents.where((d) => d['status'] == 'pending').length;
    final rejected = _documents.where((d) => d['status'] == 'rejected').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(
            top: BorderSide(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _pill('$approved approuvés', Colors.green),
          const SizedBox(width: 8),
          _pill('$pending en attente', Colors.orange),
          const SizedBox(width: 8),
          _pill('$rejected rejetés', Colors.red),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color)),
  );

  String _labelFor(dynamic type) =>
      _docLabels[type?.toString()] ?? type?.toString() ?? 'Document';
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. _DocumentReviewCard — carte individuelle d'un document
// ═════════════════════════════════════════════════════════════════════════════

class _DocumentReviewCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool isDark;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DocumentReviewCard({
    required this.doc,
    required this.isDark,
    required this.onApprove,
    required this.onReject,
  });

  static const Map<String, String> _docLabels = {
    'drivers_license': 'Permis de conduire',
    'criminal_record': 'Casier judiciaire',
    'identity_card': 'Carte d\'identité (CIN)',
    'vehicle_registration': 'Carte grise',
    'vehicle_insurance': 'Assurance véhicule',
    'tdc_permit': 'Permis TDC',
    'technical_inspection': 'Visite technique',
    'other': 'Autre document',
  };

  String get _label =>
      doc['document_label']?.toString().isNotEmpty == true
          ? doc['document_label']
          : _docLabels[doc['document_type']?.toString()] ??
          doc['document_type']?.toString() ??
          'Document';

  String get _status => doc['status']?.toString() ?? 'pending';
  String get _fileUrl => doc['file_url']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document image
          Expanded(child: _buildImagePreview(context)),

          // Info + actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      _label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusChip,
                ]),
                const SizedBox(height: 4),
                Text(
                  'Soumis le ${doc['submitted_at']?.toString().substring(0, 10) ?? 'N/A'}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                ),
                if (_status == 'rejected' &&
                    doc['rejection_reason'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Rejeté : ${doc['rejection_reason']}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (_status == 'pending' || _status == 'under_review') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approuver',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Rejeter',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                ],
                if (_status == 'approved') ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.verified,
                        color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Approuvé par ${doc['reviewed_by'] ?? 'admin'}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.green),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    if (_fileUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : Colors.grey.shade100,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Center(
          child: Icon(Icons.image_not_supported,
              color: Colors.grey.shade400, size: 48),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openFullImage(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              _fileUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: isDark
                    ? AppColors.darkBg
                    : Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          color: Colors.grey.shade400, size: 40),
                      const SizedBox(height: 6),
                      Text('Image indisponible',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: isDark
                      ? AppColors.darkBg
                      : Colors.grey.shade100,
                  child:
                  const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
          // Zoom hint
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.zoom_in,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(_fileUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _statusChip {
    final Map<String, _ChipStyle> map = {
      'pending': _ChipStyle(Colors.orange, '⏳ En attente'),
      'under_review': _ChipStyle(Colors.blue, '🔍 En révision'),
      'approved': _ChipStyle(Colors.green, '✅ Approuvé'),
      'rejected': _ChipStyle(Colors.red, '❌ Rejeté'),
    };
    final s = map[_status] ?? _ChipStyle(Colors.grey, _status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(s.label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: s.color)),
    );
  }

  Color get _borderColor {
    switch (_status) {
      case 'approved':
        return Colors.green.withOpacity(0.4);
      case 'rejected':
        return Colors.red.withOpacity(0.4);
      case 'under_review':
        return Colors.blue.withOpacity(0.4);
      default:
        return Colors.orange.withOpacity(0.3);
    }
  }
}

class _ChipStyle {
  final Color color;
  final String label;
  const _ChipStyle(this.color, this.label);
}