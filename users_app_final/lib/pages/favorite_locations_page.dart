import 'dart:async';
import 'package:flutter/material.dart';
import 'package:users_app/services/geocoding_service.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';

class FavoriteLocationsPageSupabase extends StatefulWidget {
  const FavoriteLocationsPageSupabase({super.key});

  @override
  State<FavoriteLocationsPageSupabase> createState() => _FavoriteLocationsPageSupabaseState();
}

class _FavoriteLocationsPageSupabaseState extends State<FavoriteLocationsPageSupabase> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  // ✅ Variables pour l'ajout rapide
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await SupabaseService.getFavorites();

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Erreur chargement favoris: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ RECHERCHE
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = false;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final results = await GeocodingService.searchAddress(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _showResults = results.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      print("❌ Erreur recherche: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ✅ AJOUT D'UN FAVORI
  Future<void> _addFavorite(Map<String, dynamic> place) async {
    setState(() {
      _showResults = false;
      _searchResults = [];
      _searchController.clear();
      _isLoading = true;
    });
    _searchFocusNode.unfocus();

    try {
      String name = place['main_text'] ?? "Lieu Favori";
      String address = place['secondary_text'] ?? "";
      double lat = double.tryParse(place['lat'].toString()) ?? 0.0;
      double lng = double.tryParse(place['lng'].toString()) ?? 0.0;

      await SupabaseService.addFavorite(
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lieu ajouté aux favoris!"), backgroundColor: AppColors.success),
      );

      _loadFavorites();
    } catch (e) {
      print("❌ Erreur ajout favori: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'ajout"), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _selectFavorite(Map<String, dynamic> favorite) async {
    if (!mounted) return;

    // ✅ RETOURNER LES DONNÉES DU FAVORI:
    Navigator.pop(context, {
      'latitude': favorite['latitude'],
      'longitude': favorite['longitude'],
      'address': favorite['address'],
      'name': favorite['name'],
    });
  }

  Future<void> _deleteFavorite(String favoriteId) async {
    try {
      await SupabaseService.deleteFavorite(favoriteId);

      setState(() {
        _favorites.removeWhere((fav) => fav['id'].toString() == favoriteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Favori supprimé"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur suppression favori: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Mes Favoris", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ✅ BARRE DE RECHERCHE D'AJOUT
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          _debounceTimer?.cancel();
                          _searchPlaces(value);
                        },
                        decoration: InputDecoration(
                          hintText: "Rechercher une adresse à ajouter...",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.add_location_alt, color: AppColors.primary),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : (_searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (_showResults)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.add_circle, color: AppColors.primary),
                              title: Text(place['main_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(place['secondary_text'] ?? '', maxLines: 1),
                              onTap: () => _addFavorite(place),
                            );
                          },
                        ),
                      ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ✅ LISTE DES FAVORIS
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _favorites.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final fav = _favorites[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                                key: Key(fav['id'].toString()),
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white, size: 28),
                                ),
                                onDismissed: (_) => _deleteFavorite(fav['id'].toString()),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.star, color: AppColors.primary, size: 28),
                                    ),
                                    title: Text(
                                      fav['name'] ?? 'Sans nom',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        fav['address'] ?? '',
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.directions_car, size: 24, color: AppColors.primary),
                                    onTap: () => _selectFavorite(fav),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_border,
                size: 60,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Aucun favori",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Utilisez la barre de recherche ci-dessus pour ajouter des destinations rapides.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}