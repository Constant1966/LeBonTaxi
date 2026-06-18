// lib/authentication/splash_screen_document_check.dart
//
// Remplacez / étendez votre méthode _checkAuth() existante dans splash_screen.dart
// avec cette logique de vérification du statut des documents.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mixin à ajouter à votre SplashScreen State.
/// Remplace la logique de redirection post-auth.
mixin DocumentStatusCheck<T extends StatefulWidget> on State<T> {
  final _client = Supabase.instance.client;

  Future<void> checkDocumentStatusAndNavigate(String driverId) async {
    try {
      // Fetch driver row
      final Map<String, dynamic>? driverRow = await _client
          .from('drivers')
          .select('profile_completed, verified, document_status, documents_rejection_note')
          .eq('id', driverId)
          .maybeSingle();

      if (driverRow == null) {
        // New user — go to registration
        _navigate('/registration');
        return;
      }

      final bool profileCompleted =
          driverRow['profile_completed'] as bool? ?? false;
      final bool verified = driverRow['verified'] as bool? ?? false;
      final String documentStatus =
          driverRow['document_status'] as String? ?? 'pending';

      if (!profileCompleted) {
        _navigate('/registration');
        return;
      }

      switch (documentStatus) {
        case 'pending':
        case 'under_review':
          _navigate('/waiting-verification');
          break;

        case 'documents_required':
        // Missing docs — go directly to doc upload
          _navigate('/registration/documents');
          break;

        case 'rejected':
        // Show rejected screen with re-upload option
          _navigate('/document-status',
              arguments: {'show_rejection_banner': true});
          break;

        case 'approved':
          if (verified) {
            _navigate('/home');
          } else {
            _navigate('/waiting-verification');
          }
          break;

        default:
          _navigate('/waiting-verification');
      }
    } catch (e) {
      debugPrint('[SplashScreen] checkDocumentStatus error: $e');
      _navigate('/registration');
    }
  }

  void _navigate(String route, {Object? arguments}) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting-for-verification screen (si pas encore présent dans le projet)
// ─────────────────────────────────────────────────────────────────────────────

class WaitingVerificationScreen extends StatelessWidget {
  const WaitingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top,
                  size: 80, color: Color(0xFF1A73E8)),
              const SizedBox(height: 24),
              const Text(
                'Vérification en cours',
                style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Votre dossier est en cours d\'examen par notre équipe. Vous recevrez une notification dès qu\'il sera traité.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/document-status'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Voir mes documents'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: const Text('Se déconnecter',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}