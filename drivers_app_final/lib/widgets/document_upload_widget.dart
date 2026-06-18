// lib/widgets/document_upload_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_quality_service.dart';
import '../models/driver_document_model.dart';

/// Called when a valid image file is selected and quality-checked.
typedef OnDocumentSelected = void Function(File file, ImageQualityResult quality);

/// Reusable card widget for uploading a single driver document.
/// Shows a quality badge and allows retaking the photo.
class DocumentUploadWidget extends StatefulWidget {
  final String documentType;
  final String label;
  final bool isRequired;

  /// Pre-existing status from Supabase (for re-submission flows).
  final String? existingStatus;
  final String? existingRejectionReason;
  final String? existingFileUrl;

  final OnDocumentSelected? onDocumentSelected;
  final VoidCallback? onRemove;

  const DocumentUploadWidget({
    super.key,
    required this.documentType,
    required this.label,
    this.isRequired = true,
    this.existingStatus,
    this.existingRejectionReason,
    this.existingFileUrl,
    this.onDocumentSelected,
    this.onRemove,
  });

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  File? _selectedFile;
  ImageQualityResult? _qualityResult;
  bool _isChecking = false;
  double _uploadProgress = 0;
  final ImagePicker _picker = ImagePicker();

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            if (_selectedFile != null) ...[
              _buildPreview(),
              const SizedBox(height: 8),
              if (_isChecking) _buildCheckingIndicator(),
              if (_qualityResult != null && !_isChecking) _buildQualityFeedback(),
            ] else if (widget.existingFileUrl != null) ...[
              _buildExistingDocumentInfo(),
            ] else ...[
              _buildUploadPrompt(),
            ],
            if (_uploadProgress > 0 && _uploadProgress < 1.0)
              _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(_iconForType(widget.documentType), color: Colors.grey[700], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        if (widget.isRequired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Text('Obligatoire',
                style: TextStyle(fontSize: 10, color: Colors.red[700])),
          ),
        if (widget.existingStatus != null) ...[
          const SizedBox(width: 6),
          _buildStatusBadge(widget.existingStatus!),
        ],
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return GestureDetector(
      onTap: _showSourceDialog,
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: Colors.grey[500]),
            const SizedBox(height: 6),
            Text('Appuyer pour ajouter',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showFullImage(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedFile!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              if (_qualityResult != null)
                _buildQualityBadge(_qualityResult!.badgeLevel),
              const SizedBox(width: 4),
              _buildIconButton(
                  icon: Icons.camera_alt, onTap: _showSourceDialog),
              const SizedBox(width: 4),
              _buildIconButton(
                  icon: Icons.close, onTap: _clearSelection, color: Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityFeedback() {
    final q = _qualityResult!;
    if (q.isAcceptable && q.issues.isEmpty) {
      return _infoRow(Icons.check_circle, 'Document de bonne qualité', Colors.green);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.issues.isNotEmpty)
          ...q.issues.map((i) => _infoRow(Icons.warning_amber, i, Colors.orange)),
        if (!q.isAcceptable)
          ...q.suggestions.map((s) => _infoRow(Icons.lightbulb_outline, s, Colors.blue)),
        if (!q.isAcceptable) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showSourceDialog,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Reprendre la photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[800],
                side: BorderSide(color: Colors.orange[400]!),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExistingDocumentInfo() {
    if (widget.existingStatus == 'rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.cancel, 'Document rejeté', Colors.red),
          if (widget.existingRejectionReason != null)
            _infoRow(Icons.info_outline,
                'Raison : ${widget.existingRejectionReason}', Colors.red[700]!),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSourceDialog,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Remplacer ce document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    if (widget.existingStatus == 'approved') {
      return _infoRow(Icons.verified, 'Document approuvé', Colors.green);
    }
    return _infoRow(Icons.hourglass_top, 'En attente de vérification', Colors.orange);
  }

  Widget _buildCheckingIndicator() {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text('Vérification de la qualité…',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(value: _uploadProgress),
        const SizedBox(height: 2),
        Text('Upload ${(_uploadProgress * 100).toInt()}%',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _buildQualityBadge(String level) {
    final Map<String, _BadgeStyle> styles = {
      'good': _BadgeStyle(Colors.green, Icons.check_circle),
      'warning': _BadgeStyle(Colors.orange, Icons.warning_amber),
      'error': _BadgeStyle(Colors.red, Icons.cancel),
    };
    final style = styles[level] ?? styles['warning']!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(style.icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, _BadgeStyle> map = {
      'pending': _BadgeStyle(Colors.orange, Icons.hourglass_top),
      'approved': _BadgeStyle(Colors.green, Icons.verified),
      'rejected': _BadgeStyle(Colors.red, Icons.cancel),
    };
    final s = map[status] ?? map['pending']!;
    return Icon(s.icon, color: s.color, size: 18);
  }

  Widget _buildIconButton(
      {required IconData icon,
      required VoidCallback onTap,
      Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Expanded(
              child: Text(text, style: TextStyle(fontSize: 11, color: color))),
        ],
      ),
    );
  }

  Color get _borderColor {
    if (_qualityResult != null && !_qualityResult!.isAcceptable) {
      return Colors.red[300]!;
    }
    if (widget.existingStatus == 'rejected') return Colors.red[300]!;
    if (widget.existingStatus == 'approved') return Colors.green[300]!;
    if (_selectedFile != null && _qualityResult?.isAcceptable == true) {
      return Colors.green[300]!;
    }
    return Colors.grey[300]!;
  }

  // ── Image picking ──────────────────────────────────────────────────────

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? xFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (xFile == null) return;

    setState(() {
      _selectedFile = File(xFile.path);
      _qualityResult = null;
      _isChecking = true;
    });

    final result = await ImageQualityService.checkFile(_selectedFile!);

    if (!mounted) return;
    setState(() {
      _qualityResult = result;
      _isChecking = false;
    });

    if (result.isAcceptable) {
      widget.onDocumentSelected?.call(_selectedFile!, result);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _qualityResult = null;
      _uploadProgress = 0;
    });
  }

  void _showFullImage(BuildContext context) {
    if (_selectedFile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(file: _selectedFile!),
      ),
    );
  }

  /// External method to update upload progress (called by parent).
  void setUploadProgress(double progress) {
    if (mounted) setState(() => _uploadProgress = progress);
  }

  IconData _iconForType(String type) {
    const Map<String, IconData> icons = {
      'drivers_license': Icons.badge,
      'criminal_record': Icons.gavel,
      'identity_card': Icons.credit_card,
      'vehicle_registration': Icons.directions_car,
      'vehicle_insurance': Icons.security,
      'tdc_permit': Icons.assignment,
      'technical_inspection': Icons.build,
      'other': Icons.attach_file,
    };
    return icons[type] ?? Icons.description;
  }
}

class _BadgeStyle {
  final Color color;
  final IconData icon;
  const _BadgeStyle(this.color, this.icon);
}

class _FullImageViewer extends StatelessWidget {
  final File file;
  const _FullImageViewer({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
