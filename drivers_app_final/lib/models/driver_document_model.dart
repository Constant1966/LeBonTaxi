// lib/models/driver_document_model.dart

class DriverDocument {
  final String id;
  final String driverId;
  final String documentType;
  final String? documentLabel;
  final String fileUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final DateTime updatedAt;

  const DriverDocument({
    required this.id,
    required this.driverId,
    required this.documentType,
    this.documentLabel,
    required this.fileUrl,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    required this.submittedAt,
    this.reviewedAt,
    required this.updatedAt,
  });

  factory DriverDocument.fromMap(Map<String, dynamic> map) {
    return DriverDocument(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      documentType: map['document_type'] as String,
      documentLabel: map['document_label'] as String?,
      fileUrl: map['file_url'] as String,
      status: map['status'] as String? ?? 'pending',
      rejectionReason: map['rejection_reason'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'document_type': documentType,
      'document_label': documentLabel,
      'file_url': fileUrl,
      'status': status,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DriverDocument copyWith({
    String? status,
    String? rejectionReason,
    String? fileUrl,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return DriverDocument(
      id: id,
      driverId: driverId,
      documentType: documentType,
      documentLabel: documentLabel,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      updatedAt: DateTime.now(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get displayLabel {
    if (documentLabel != null && documentLabel!.isNotEmpty) return documentLabel!;
    return defaultLabels[documentType] ?? documentType;
  }

  static const Map<String, String> defaultLabels = {
    'drivers_license': 'Permis de conduire',
    'criminal_record': 'Casier judiciaire',
    'identity_card': 'Carte d\'identité (CIN)',
    'vehicle_registration': 'Carte grise du véhicule',
    'vehicle_insurance': 'Assurance véhicule',
    'tdc_permit': 'Permis TDC',
    'technical_inspection': 'Visite technique',
    'other': 'Autre document',
  };

  static const List<String> requiredDocumentTypes = [
    'drivers_license',
    'criminal_record',
    'identity_card',
    'vehicle_registration',
    'vehicle_insurance',
  ];

  static const List<String> allDocumentTypes = [
    'drivers_license',
    'criminal_record',
    'identity_card',
    'vehicle_registration',
    'vehicle_insurance',
    'tdc_permit',
    'technical_inspection',
    'other',
  ];
}