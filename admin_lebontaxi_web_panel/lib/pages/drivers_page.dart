import '../constants/app_colors.dart';
import '../methods/common_methods.dart';
import '../widgets/drivers_data_list.dart';
import 'package:flutter/material.dart';
import '../services/export_service.dart';

// Page pour afficher et gérer les chauffeurs
class DriversPage extends StatefulWidget
{
  static const String id = "\webPageDrivers";

  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage>
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                      "Gérer les Chauffeurs",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Consultez, recherchez et gérez les comptes des chauffeurs.",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ExportService.exportDrivers();
                      if (context.mounted) cMethods.showSnackBar(context, "✅ Export CSV téléchargé !");
                    } catch (e) {
                      if (context.mounted) cMethods.showSnackBar(context, "❌ Erreur: $e");
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text("Exporter CSV", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // Emerald green for CSV
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Barre de recherche
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: "Rechercher un chauffeur par nom, téléphone ou véhicule...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 15),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                      onSubmitted: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
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

            const SizedBox(height: 32),

            // Grille de données
            Expanded(
              child: DriversDataList(searchQuery: searchQuery),
            ),
          ],
        ),
      ),
    );
  }
}
