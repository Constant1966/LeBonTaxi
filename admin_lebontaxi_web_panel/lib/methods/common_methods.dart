import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// Classe contenant des méthodes et des widgets communs à travers l'application
class CommonMethods
{
  // Widget d'en-tête pour les tableaux
  Widget header(int headerFlexValue, String headerTitle, {bool isDark = false})
  {
    return Expanded(
      flex: headerFlexValue,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardHover : AppColors.primary.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            headerTitle,
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // Widget de cellule de données pour les tableaux
  Widget data(int dataFlexValue, Widget widget, {bool isDark = false})
  {
    return Expanded(
      flex: dataFlexValue,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          border: Border.all(color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : Colors.grey.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: widget,
        ),
      ),
    );
  }

  // Affiche une boîte de dialogue de confirmation
  Future<bool> showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.card(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title, style: TextStyle(color: AppColors.textPrimary(isDark))),
          content: Text(message, style: TextStyle(color: AppColors.textSecondary(isDark))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "Annuler",
                style: TextStyle(color: AppColors.textSecondary(isDark)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Confirmer"),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Affiche un message de succès ou d'erreur (Design professionnel façon Top Toast)
  void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Fermer le snackbar actuel pour éviter l'empilement
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isError ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: isError ? (isDark ? Colors.redAccent : Colors.red) : (isDark ? Colors.greenAccent : Colors.green),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 120, // Pousse le toast vers le haut
            left: MediaQuery.of(context).size.width > 600 ? MediaQuery.of(context).size.width / 2 - 200 : 20,
            right: MediaQuery.of(context).size.width > 600 ? MediaQuery.of(context).size.width / 2 - 200 : 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
        ),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Construit un badge de statut (Actif/Bloqué) — adapté dark mode
  Widget buildStatusBadge(String status, {bool isDark = false}) {
    final bool isActive = status == "no";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive 
          ? (isDark ? AppColors.success.withValues(alpha: 0.15) : Colors.green.shade50) 
          : (isDark ? AppColors.danger.withValues(alpha: 0.15) : Colors.red.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive 
            ? (isDark ? AppColors.success.withValues(alpha: 0.4) : Colors.green.shade200)
            : (isDark ? AppColors.danger.withValues(alpha: 0.4) : Colors.red.shade200),
        ),
      ),
      child: Text(
        isActive ? "Actif" : "Bloqué",
        style: TextStyle(
          color: isActive 
            ? (isDark ? const Color(0xFF34D399) : Colors.green.shade700) 
            : (isDark ? const Color(0xFFF87171) : Colors.red.shade700),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
