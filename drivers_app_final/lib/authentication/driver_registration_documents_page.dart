// lib/authentication/driver_registration_documents_page.dart
//
// Remplace la Page 3 existante (permis seul) par une section complète de documents.
// Ajoute une Page 4 de récapitulatif avant soumission finale.
//
// Intégrez ce fichier en remplaçant/étendant votre driver_registration_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_document_model.dart';
import '../services/image_quality_service.dart';
import '../services/supabase_document_service.dart';
import '../widgets/document_upload_widget.dart';
import '../global/global_var.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 : Upload des documents obligatoires
// ─────────────────────────────────────────────────────────────────────────────

class RegistrationDocumentsPage extends StatefulWidget {
  final VoidCallback onNext;
  final Map<String, File?> initialFiles;
  final void Function(Map<String, File?> files, Map<String, ImageQualityResult?> qualities) onFilesChanged;

  const RegistrationDocumentsPage({
    super.key,
    required this.onNext,
    required this.initialFiles,
    required this.onFilesChanged,
  });

  @override
  State<RegistrationDocumentsPage> createState() =>
      _RegistrationDocumentsPageState();
}

class _RegistrationDocumentsPageState
    extends State<RegistrationDocumentsPage> {
  final Map<String, File?> _files = {};
  final Map<String, ImageQualityResult?> _qualities = {};

  static const List<_DocConfig> _requiredDocs = [
    _DocConfig('drivers_license', 'Permis de conduire', true),
    _DocConfig('criminal_record', 'Casier judiciaire (B3)', true),
    _DocConfig('identity_card', 'Carte d\'identité nationale (CIN)', true),
    _DocConfig('vehicle_registration', 'Carte grise du véhicule', true),
    _DocConfig('vehicle_insurance', 'Assurance véhicule', true),
    _DocConfig('tdc_permit', 'Permis TDC (Transport De Commande)', false),
    _DocConfig('other', 'Autre document (optionnel)', false),
  ];

  @override
  void initState() {
    super.initState();
    _files.addAll(widget.initialFiles);
  }

  bool get _canProceed {
    const required = [
      'drivers_license',
      'criminal_record',
      'identity_card',
      'vehicle_registration',
      'vehicle_insurance',
    ];
    return required.every((type) {
      final file = _files[type];
      final quality = _qualities[type];
      return file != null && quality != null && quality.isAcceptable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                ..._requiredDocs.map((cfg) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DocumentUploadWidget(
                    documentType: cfg.type,
                    label: cfg.label,
                    isRequired: cfg.isRequired,
                    onDocumentSelected: (file, quality) {
                      setState(() {
                        _files[cfg.type] = file;
                        _qualities[cfg.type] = quality;
                      });
                      widget.onFilesChanged(_files, _qualities);
                    },
                  ),
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildHeader() {
    final total = _requiredDocs.where((d) => d.isRequired).length;
    final done = _requiredDocs
        .where((d) => d.isRequired)
        .where((d) =>
    _files[d.type] != null && _qualities[d.type]?.isAcceptable == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Documents requis : $done/$total',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: total > 0 ? done / total : 0,
            backgroundColor: Colors.blue[100],
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          const Text(
            'Assurez-vous que vos photos sont nettes, bien éclairées et que le texte est lisible.',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: Column(
        children: [
          if (!_canProceed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Veuillez soumettre tous les documents obligatoires avec une bonne qualité.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                backgroundColor: const Color(0xFF1A73E8),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Continuer — Récapitulatif',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 : Récapitulatif des documents avant soumission
// ─────────────────────────────────────────────────────────────────────────────

class RegistrationDocumentsSummaryPage extends StatefulWidget {
  final Map<String, File?> files;
  final Map<String, ImageQualityResult?> qualities;
  final String driverId;

  /// Called when all documents have been successfully uploaded to Supabase.
  final VoidCallback onSubmitSuccess;

  const RegistrationDocumentsSummaryPage({
    super.key,
    required this.files,
    required this.qualities,
    required this.driverId,
    required this.onSubmitSuccess,
  });

  @override
  State<RegistrationDocumentsSummaryPage> createState() =>
      _RegistrationDocumentsSummaryPageState();
}

class _RegistrationDocumentsSummaryPageState
    extends State<RegistrationDocumentsSummaryPage> {
  final _client = Supabase.instance.client;
  bool _submitting = false;
  final Map<String, double> _progress = {};
  String? _error;

  Future<void> _submitAllDocuments() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      for (final entry in widget.files.entries) {
        final type = entry.key;
        final file = entry.value;
        if (file == null) continue;

        setState(() => _progress[type] = 0.1);

        final url = await _client.uploadDocumentFile(
          driverId: widget.driverId,
          documentType: type,
          file: file,
          onProgress: (p) => setState(() => _progress[type] = p),
        );

        setState(() => _progress[type] = 0.85);

        await _client.submitDocument(
          driverId: widget.driverId,
          documentType: type,
          fileUrl: url,
        );

        setState(() => _progress[type] = 1.0);
      }

      // Mark profile as completed
      await _client.from('drivers').update({
        'profile_completed': true,
        'document_status': 'under_review',
      }).eq('id', widget.driverId);

      // ✅ Email de confirmation de réception du dossier
      try {
        await _client.functions.invoke(
          'send-driver-email',
          body: {
            'to': driverEmail,
            'subject': '📋 Dossier reçu — Le Bon Taxi',
            'html': _buildConfirmationEmailHtml(),
          },
        );
      } catch (emailError) {
        print('[Email] Erreur envoi confirmation: $emailError');
      }

      widget.onSubmitSuccess();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  String _buildConfirmationEmailHtml() {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <tr><td style="background:#6366F1;padding:32px 40px;text-align:center;">
          <div style="font-size:48px;margin-bottom:12px;">📋</div>
          <h1 style="color:#fff;margin:0;font-size:22px;font-weight:700;">Dossier reçu !</h1>
        </td></tr>
        <tr><td style="background:#1E1B4B;padding:10px 40px;text-align:center;">
          <span style="color:#fff;font-size:16px;font-weight:700;">🚕 Le Bon Taxi</span>
        </td></tr>
        <tr><td style="padding:32px 40px;">
          <p style="color:#374151;font-size:16px;margin:0 0 16px;">Bonjour <strong>$driverName</strong>,</p>
          <p style="color:#4B5563;font-size:15px;line-height:1.7;margin:0 0 24px;">
            Nous avons bien reçu votre dossier complet. Nos équipes vont vérifier vos documents dans les <strong>24 à 48 heures</strong>.
          </p>
          <div style="background:#EEF2FF;border-left:4px solid #6366F1;padding:14px 18px;border-radius:0 10px 10px 0;margin:0 0 24px;">
            <strong style="color:#4338CA;">Prochaine étape :</strong><br>
            <span style="color:#4B5563;font-size:14px;">Vous recevrez un email dès que votre dossier sera approuvé ou si des corrections sont nécessaires.</span>
          </div>
          <p style="color:#6B7280;font-size:13px;margin:0;">
            Questions ? <a href="mailto:constantlorvenson@gmail.com" style="color:#6366F1;">constantlorvenson@gmail.com</a> ou 
            <a href="https://wa.me/50946894905" style="color:#25D366;">WhatsApp +509 46 89 49 05</a>
          </p>
        </td></tr>
        <tr><td style="padding:20px 40px;text-align:center;border-top:1px solid #E5E7EB;">
          <p style="color:#9CA3AF;font-size:12px;margin:0;">© $year Le Bon Taxi — Haïti</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final docEntries = widget.files.entries
        .where((MapEntry<String, File?> e) => e.value != null)
        .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeader(docEntries.length),
                const SizedBox(height: 16),
                ...docEntries.map((MapEntry<String, File?> e) => _buildDocRow(e.key, e.value!)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorCard(),
                ],
                const SizedBox(height: 16),
                _buildInfoCard(),
              ],
            ),
          ),
        ),
        _buildSubmitBar(docEntries.length),
      ],
    );
  }

  Widget _buildSummaryHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count document(s) prêt(s)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.green)),
                const Text(
                  'Vérifiez vos documents avant de soumettre.',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String type, File file) {
    final label = DriverDocument.defaultLabels[type] ?? type;
    final quality = widget.qualities[type];
    final progress = _progress[type] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(file, width: 52, height: 52, fit: BoxFit.cover),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quality != null
                  ? quality.statusLabel
                  : 'Qualité non vérifiée',
              style: TextStyle(
                  fontSize: 11,
                  color: quality?.isAcceptable == true
                      ? Colors.green
                      : Colors.orange),
            ),
            if (_submitting && progress > 0) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ],
        ),
        trailing: progress >= 1.0
            ? const Icon(Icons.cloud_done, color: Colors.green)
            : Icon(Icons.image, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 18, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La vérification de vos documents prend généralement 24 à 48 heures. Vous recevrez une notification dès qu\'un document est examiné.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Erreur : $_error',
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submitAllDocuments,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF1A73E8),
            disabledBackgroundColor: Colors.grey[300],
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _submitting
              ? const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Envoi en cours…',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          )
              : Text(
            'Soumettre $count document(s)',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Internal data class ────────────────────────────────────────────────────────

class _DocConfig {
  final String type;
  final String label;
  final bool isRequired;
  const _DocConfig(this.type, this.label, this.isRequired);
}