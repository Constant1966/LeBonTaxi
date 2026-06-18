// lib/services/supabase_document_service.dart
//
// Paste these methods into your existing SupabaseService class,
// or use this file as a standalone mixin / extension.
//
// Depends on:
//   - supabase_flutter
//   - ../models/driver_document_model.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_document_model.dart';

/// Extension on SupabaseClient that adds all document-related operations.
extension SupabaseDocumentService on SupabaseClient {
  // ── Storage bucket ───────────────────────────────────────────────────

  /// Upload [file] to the `driver_documents` bucket and return its public URL.
  Future<String> uploadDocumentFile({
    required String driverId,
    required String documentType,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final String ext = file.path.split('.').last.toLowerCase();
    final String path = '$driverId/$documentType/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await storage.from('driver_documents').upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: false),
    );

    final String publicUrl =
    storage.from('driver_documents').getPublicUrl(path);
    return publicUrl;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// Insert a new document record. Returns the created [DriverDocument].
  Future<DriverDocument> submitDocument({
    required String driverId,
    required String documentType,
    required String fileUrl,
    String? documentLabel,
  }) async {
    final Map<String, dynamic> data = await from('driver_documents').insert({
      'driver_id': driverId,
      'document_type': documentType,
      'document_label': documentLabel,
      'file_url': fileUrl,
      'status': 'pending',
    }).select().single();

    // Update driver's document_status to 'under_review' if was pending
    await from('drivers')
        .update({'document_status': 'under_review'})
        .eq('id', driverId)
        .eq('document_status', 'pending');

    return DriverDocument.fromMap(data);
  }

  /// Fetch all documents for [driverId], ordered by submission date.
  Future<List<DriverDocument>> getDriverDocuments(String driverId) async {
    final List<dynamic> rows = await from('driver_documents')
        .select()
        .eq('driver_id', driverId)
        .order('submitted_at', ascending: false);

    return rows
        .map((r) => DriverDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch documents filtered by [status].
  Future<List<DriverDocument>> getDocumentsByStatus(
      String driverId, String status) async {
    final List<dynamic> rows = await from('driver_documents')
        .select()
        .eq('driver_id', driverId)
        .eq('status', status)
        .order('submitted_at', ascending: false);

    return rows
        .map((r) => DriverDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Replace the file of a rejected document and reset its status to 'pending'.
  Future<DriverDocument> resubmitDocument({
    required String documentId,
    required String newFileUrl,
  }) async {
    final Map<String, dynamic> data = await from('driver_documents')
        .update({
      'file_url': newFileUrl,
      'status': 'pending',
      'rejection_reason': null,
      'reviewed_by': null,
      'reviewed_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', documentId)
        .select()
        .single();

    return DriverDocument.fromMap(data);
  }

  // ── Realtime ──────────────────────────────────────────────────────────

  /// Subscribe to document status changes for [driverId].
  /// Returns the [RealtimeChannel] so the caller can cancel it.
  RealtimeChannel subscribeToDocumentUpdates(
      String driverId,
      void Function(DriverDocument updated) onUpdate,
      ) {
    return channel('driver_documents:$driverId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'driver_documents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'driver_id',
        value: driverId,
      ),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          onUpdate(DriverDocument.fromMap(payload.newRecord));
        }
      },
    )
        .subscribe();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Returns true when all required document types have been submitted
  /// (regardless of approval status).
  Future<bool> hasSubmittedAllRequiredDocuments(String driverId) async {
    final docs = await getDriverDocuments(driverId);
    final submittedTypes = docs.map((d) => d.documentType).toSet();
    return DriverDocument.requiredDocumentTypes
        .every((type) => submittedTypes.contains(type));
  }

  /// Returns the list of required types that are still missing.
  Future<List<String>> getMissingRequiredDocumentTypes(
      String driverId) async {
    final docs = await getDriverDocuments(driverId);
    final submittedTypes = docs.map((d) => d.documentType).toSet();
    return DriverDocument.requiredDocumentTypes
        .where((type) => !submittedTypes.contains(type))
        .toList();
  }
}