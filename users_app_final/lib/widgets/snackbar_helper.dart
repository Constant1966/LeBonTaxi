import 'package:flutter/material.dart';

/// Helper SnackBar professionnel et élégant pour l'app utilisateur Le Bon Taxi
/// Utilisation :
///   SnackBarHelper.showSuccess(context, "Message envoyé !");
///   SnackBarHelper.showError(context, "Erreur de connexion");
///   SnackBarHelper.showInfo(context, "Chargement en cours...");
///   SnackBarHelper.showWarning(context, "Connexion instable");
class SnackBarHelper {
  /// ✅ Succès — vert avec icône check
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, _SnackType.success);
  }

  /// ❌ Erreur — rouge avec icône erreur
  static void showError(BuildContext context, String message) {
    _show(context, message, _SnackType.error);
  }

  /// ℹ️ Info — bleu avec icône info
  static void showInfo(BuildContext context, String message) {
    _show(context, message, _SnackType.info);
  }

  /// ⚠️ Warning — orange avec icône attention
  static void showWarning(BuildContext context, String message) {
    _show(context, message, _SnackType.warning);
  }

  static void _show(BuildContext context, String message, _SnackType type) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fermer le snackbar actuel pour éviter l'empilement
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type, isDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Icône avec fond coloré
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: config.iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: config.iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            // Message
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Bouton fermer
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? config.borderColor.withOpacity(0.3)
                : config.borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        elevation: 8,
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static _SnackConfig _getConfig(_SnackType type, bool isDark) {
    switch (type) {
      case _SnackType.success:
        return _SnackConfig(
          icon: Icons.check_circle_rounded,
          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
          iconBgColor: isDark
              ? const Color(0xFF10B981).withOpacity(0.15)
              : const Color(0xFF10B981).withOpacity(0.1),
          borderColor: const Color(0xFF10B981),
        );
      case _SnackType.error:
        return _SnackConfig(
          icon: Icons.error_rounded,
          iconColor: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
          iconBgColor: isDark
              ? const Color(0xFFEF4444).withOpacity(0.15)
              : const Color(0xFFEF4444).withOpacity(0.1),
          borderColor: const Color(0xFFEF4444),
        );
      case _SnackType.info:
        return _SnackConfig(
          icon: Icons.info_rounded,
          iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
          iconBgColor: isDark
              ? const Color(0xFF3B82F6).withOpacity(0.15)
              : const Color(0xFF3B82F6).withOpacity(0.1),
          borderColor: const Color(0xFF3B82F6),
        );
      case _SnackType.warning:
        return _SnackConfig(
          icon: Icons.warning_amber_rounded,
          iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
          iconBgColor: isDark
              ? const Color(0xFFF59E0B).withOpacity(0.15)
              : const Color(0xFFF59E0B).withOpacity(0.1),
          borderColor: const Color(0xFFF59E0B),
        );
    }
  }
}

enum _SnackType { success, error, info, warning }

class _SnackConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;

  const _SnackConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
  });
}
