import '../constants/app_colors.dart';
import '../widgets/users_data_list.dart';
import 'package:flutter/material.dart';
import '../methods/common_methods.dart';
import '../services/export_service.dart';

// Page pour afficher et gérer les utilisateurs
class UsersPage extends StatefulWidget
{
  static const String id = "\webPageUsers";

  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
{
  CommonMethods cMethods = CommonMethods();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section d'en-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gérer les utilisateurs",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Afficher et gérer tous les utilisateurs enregistrés",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await ExportService.exportUsers();
                          if (context.mounted) cMethods.showSnackBar(context, "✅ Export CSV téléchargé !");
                        } catch (e) {
                          if (context.mounted) cMethods.showSnackBar(context, "❌ Erreur: $e");
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("Exporter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        elevation: 0,
                        side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Barre de recherche
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "Rechercher par nom, e-mail ou téléphone...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = "";
                        });
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tableau de données
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // En-tête du tableau
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : const Color(0xFF6366F1).withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          cMethods.header(2, "ID UTILISATEUR", isDark: isDark),
                          cMethods.header(1, "NOM", isDark: isDark),
                          cMethods.header(1, "E-MAIL", isDark: isDark),
                          cMethods.header(1, "TÉLÉPHONE", isDark: isDark),
                          cMethods.header(1, "STATUT", isDark: isDark),
                          cMethods.header(1, "ACTION", isDark: isDark),
                        ],
                      ),
                    ),

                    // Données du tableau
                    Expanded(
                      child: SingleChildScrollView(
                        child: UsersDataList(searchQuery: searchQuery),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
