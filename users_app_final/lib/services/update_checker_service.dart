import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateCheckerService {
  static Future<bool> checkForUpdate(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('app_settings').select('user_app_version, user_app_url').eq('id', 1).maybeSingle();
      
      if (response == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final remoteVersion = response['user_app_version'];
      final downloadUrl = response['user_app_url'];

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Colors.blue, size: 28),
            const SizedBox(width: 10),
            const Text('Mise à jour disponible'),
          ],
        ),
        content: const Text(
          'Une nouvelle version de l\'application Le Bon Taxi est disponible. Veuillez télécharger la mise à jour pour continuer à l\'utiliser.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (downloadUrl.isNotEmpty) {
                final url = Uri.parse(downloadUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('Mettre à jour maintenant'),
          ),
        ],
      ),
    );
  }
}
