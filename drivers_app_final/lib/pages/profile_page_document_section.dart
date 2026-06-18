// lib/pages/profile_page_document_section.dart
//
// Ajoutez ce widget dans votre profile_page.dart existant,
// dans la liste des options du profil.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Section "Documents" à insérer dans votre profil chauffeur.
/// Affiche le badge de statut et redirige vers DocumentStatusPage.
class ProfileDocumentSection extends StatefulWidget {
  const ProfileDocumentSection({super.key});

  @override
  State<ProfileDocumentSection> createState() =>
      _ProfileDocumentSectionState();
}

class _ProfileDocumentSectionState extends State<ProfileDocumentSection> {
  String _documentStatus = 'pending';
  int _rejectedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      // Fetch driver document_status
      final driverRow = await Supabase.instance.client
          .from('drivers')
          .select('document_status')
          .eq('id', uid)
          .maybeSingle();

      // Count rejected documents
      final rejectedRows = await Supabase.instance.client
          .from('driver_documents')
          .select('id')
          .eq('driver_id', uid)
          .eq('status', 'rejected');

      if (!mounted) return;
      setState(() {
        _documentStatus = driverRow?['document_status'] as String? ?? 'pending';
        _rejectedCount = (rejectedRows as List).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Documents',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.5),
          ),
        ),
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 22),
          ),
          title: const Text('Mes documents',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_statusLabel,
              style: TextStyle(fontSize: 12, color: _statusColor)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_rejectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_rejectedCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
          onTap: () =>
              Navigator.pushNamed(context, '/document-status').then((_) {
                _loadStatus(); // refresh on return
              }),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Color get _statusColor {
    switch (_documentStatus) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      case 'documents_required':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (_documentStatus) {
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      case 'under_review':
        return Icons.manage_search;
      case 'documents_required':
        return Icons.upload_file;
      default:
        return Icons.hourglass_top;
    }
  }

  String get _statusLabel {
    switch (_documentStatus) {
      case 'approved':
        return 'Tous les documents approuvés';
      case 'rejected':
        return '$_rejectedCount document(s) à remplacer';
      case 'under_review':
        return 'Vérification en cours';
      case 'documents_required':
        return 'Documents manquants à soumettre';
      default:
        return 'En attente de vérification';
    }
  }
}