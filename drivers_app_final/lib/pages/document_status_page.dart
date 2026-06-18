// lib/pages/document_status_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_document_model.dart';
import '../services/supabase_document_service.dart';
import '../services/image_quality_service.dart';
import '../widgets/document_upload_widget.dart';

class DocumentStatusPage extends StatefulWidget {
  const DocumentStatusPage({super.key});

  @override
  State<DocumentStatusPage> createState() => _DocumentStatusPageState();
}

class _DocumentStatusPageState extends State<DocumentStatusPage> {
  final _client = Supabase.instance.client;
  List<DriverDocument> _documents = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  String get _driverId => _client.auth.currentUser!.id;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await _client.getDriverDocuments(_driverId);
      setState(() {
        _documents = docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _channel = _client.subscribeToDocumentUpdates(_driverId, (updated) {
      setState(() {
        final idx = _documents.indexWhere((d) => d.id == updated.id);
        if (idx >= 0) {
          _documents[idx] = updated;
        } else {
          _documents.insert(0, updated);
        }
      });
      _showStatusChangedSnackbar(updated);
    });
  }

  // ── Resubmit flow ──────────────────────────────────────────────────────

  Future<void> _resubmitDocument(DriverDocument doc) async {
    // Let the user pick a new image
    File? newFile;
    ImageQualityResult? quality;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ResubmitSheet(
        doc: doc,
        onFileSelected: (f, q) {
          newFile = f;
          quality = q;
          Navigator.pop(ctx);
        },
      ),
    );

    if (newFile == null || quality == null || !quality!.isAcceptable) return;

    try {
      _showLoadingDialog('Envoi du document…');

      final newUrl = await _client.uploadDocumentFile(
        driverId: _driverId,
        documentType: doc.documentType,
        file: newFile!,
      );

      final updated = await _client.resubmitDocument(
        documentId: doc.id,
        newFileUrl: newUrl,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      setState(() {
        final idx = _documents.indexWhere((d) => d.id == doc.id);
        if (idx >= 0) _documents[idx] = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document remplacé avec succès ✓'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Statut des documents'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildTimeline(),
                      const SizedBox(height: 16),
                      const Text(
                        'Documents soumis',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ..._buildDocumentCards(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final approved = _documents.where((d) => d.isApproved).length;
    final rejected = _documents.where((d) => d.isRejected).length;
    final pending = _documents.where((d) => d.isPending).length;
    final total = DriverDocument.requiredDocumentTypes.length;

    Color headerColor = Colors.orange;
    String headerText = 'En attente de vérification';
    IconData headerIcon = Icons.hourglass_top;

    if (rejected > 0) {
      headerColor = Colors.red;
      headerText = '$rejected document(s) rejeté(s)';
      headerIcon = Icons.cancel;
    } else if (approved == total) {
      headerColor = Colors.green;
      headerText = 'Tous les documents approuvés !';
      headerIcon = Icons.verified;
    } else if (approved > 0) {
      headerColor = Colors.blue;
      headerText = '$approved/$total documents approuvés';
      headerIcon = Icons.fact_check;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(headerText,
                      style: TextStyle(
                          color: headerColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('$approved', 'Approuvés', Colors.green),
                _statChip('$pending', 'En attente', Colors.orange),
                _statChip('$rejected', 'Rejetés', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTimeline() {
    final steps = [
      _TimelineStep(
        'Soumission des documents',
        _documents.isNotEmpty,
        _documents.isNotEmpty,
      ),
      _TimelineStep(
        'Vérification en cours',
        _documents.any((d) => d.isPending),
        _documents.isNotEmpty,
      ),
      _TimelineStep(
        'Documents approuvés',
        _documents.isNotEmpty &&
            _documents
                .where((d) =>
                    DriverDocument.requiredDocumentTypes
                        .contains(d.documentType))
                .every((d) => d.isApproved),
        false,
      ),
      _TimelineStep(
        'Profil activé',
        false,
        false,
      ),
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Processus de vérification',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((e) {
              final isLast = e.key == steps.length - 1;
              return _buildTimelineStep(e.value, isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(_TimelineStep step, bool isLast) {
    final color = step.isDone
        ? Colors.green
        : step.isActive
            ? Colors.orange
            : Colors.grey[300]!;
    final icon = step.isDone ? Icons.check_circle : Icons.radio_button_unchecked;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 20),
            if (!isLast)
              Container(
                  width: 2, height: 28, color: color.withOpacity(0.4)),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: 13,
              color: step.isDone ? Colors.black87 : Colors.grey[600],
              fontWeight:
                  step.isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDocumentCards() {
    if (_documents.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Aucun document soumis',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ];
    }

    return _documents.map((doc) => _DocumentCard(
          doc: doc,
          onResubmit: () => _resubmitDocument(doc),
        )).toList();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadDocuments, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showStatusChangedSnackbar(DriverDocument doc) {
    if (!mounted) return;
    final msg = doc.isApproved
        ? '✅ ${doc.displayLabel} approuvé !'
        : doc.isRejected
            ? '❌ ${doc.displayLabel} rejeté'
            : '📋 ${doc.displayLabel} mis à jour';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: doc.isApproved ? Colors.green : Colors.orange,
      ),
    );
  }
}

// ── Document card ──────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final DriverDocument doc;
  final VoidCallback onResubmit;

  const _DocumentCard({required this.doc, required this.onResubmit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.displayLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                _statusBadge,
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Soumis le ${_formatDate(doc.submittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            if (doc.isRejected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motif du rejet :',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[800])),
                    const SizedBox(height: 2),
                    Text(
                      doc.rejectionReason ?? 'Non spécifié',
                      style:
                          TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResubmit,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Remplacer ce document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget get _statusIcon {
    if (doc.isApproved) return const Icon(Icons.verified, color: Colors.green, size: 22);
    if (doc.isRejected) return const Icon(Icons.cancel, color: Colors.red, size: 22);
    return const Icon(Icons.hourglass_top, color: Colors.orange, size: 22);
  }

  Widget get _statusBadge {
    final Map<String, _Badge> map = {
      'pending': _Badge('En attente', Colors.orange[100]!, Colors.orange[800]!),
      'approved': _Badge('Approuvé', Colors.green[100]!, Colors.green[800]!),
      'rejected': _Badge('Rejeté', Colors.red[100]!, Colors.red[800]!),
    };
    final b = map[doc.status] ?? map['pending']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: b.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(b.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: b.fg)),
    );
  }

  Color get _borderColor {
    if (doc.isApproved) return Colors.green[200]!;
    if (doc.isRejected) return Colors.red[200]!;
    return Colors.orange[200]!;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _Badge {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);
}

// ── Resubmit bottom sheet ──────────────────────────────────────────────────────

class _ResubmitSheet extends StatelessWidget {
  final DriverDocument doc;
  final void Function(File, ImageQualityResult) onFileSelected;

  const _ResubmitSheet({required this.doc, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remplacer : ${doc.displayLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DocumentUploadWidget(
            documentType: doc.documentType,
            label: doc.displayLabel,
            onDocumentSelected: onFileSelected,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Timeline data class ────────────────────────────────────────────────────────

class _TimelineStep {
  final String label;
  final bool isDone;
  final bool isActive;
  const _TimelineStep(this.label, this.isDone, this.isActive);
}
