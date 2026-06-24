import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateCheckerService {
  static Future<bool> checkForUpdate(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('app_settings').select('driver_app_version, driver_app_url').eq('id', 1).maybeSingle();
      
      if (response == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final remoteVersion = response['driver_app_version'];
      final downloadUrl = response['driver_app_url'];

      if (remoteVersion != null && _isUpdateAvailable(currentVersion, remoteVersion.toString())) {
        if (context.mounted) {
          _showUpdateDialog(context, downloadUrl?.toString() ?? '');
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Update check failed: $e');
      return false;
    }
  }

  static bool _isUpdateAvailable(String currentVersion, String remoteVersion) {
    try {
      // Nettoyer les versions (ex: 1.0.0+1 -> 1.0.0)
      final cVersion = currentVersion.split('+')[0];
      final rVersion = remoteVersion.split('+')[0];

      final currentParts = cVersion.split('.').map(int.parse).toList();
      final remoteParts = rVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < currentParts.length && i < remoteParts.length; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return remoteParts.length > currentParts.length;
    } catch (e) {
      return false;
    }
  }

  static void _showUpdateDialog(BuildContext context, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text('Mise \u00e0 jour requise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Une nouvelle version de l\'application Le Bon Taxi Chauffeur est disponible. Veuillez t\u00e9l\u00e9charger la mise \u00e0 jour pour recevoir de nouvelles courses.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Plus tard', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (downloadUrl.isNotEmpty) {
                final url = Uri.parse(downloadUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            label: const Text('Mettre \u00e0 jour', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
