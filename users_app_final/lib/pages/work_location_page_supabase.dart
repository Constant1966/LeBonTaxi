import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:users_app/services/geocoding_service.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/widgets/snackbar_helper.dart';

class WorkLocationPageSupabase extends StatefulWidget {
  const WorkLocationPageSupabase({super.key});

  @override
  State<WorkLocationPageSupabase> createState() => _WorkLocationPageSupabaseState();
}

class _WorkLocationPageSupabaseState extends State<WorkLocationPageSupabase> {
  final _addressController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSaving = false;
  
  String? _savedAddress;
  double? _savedLat;
  double? _savedLng;

  double? _selectedLat;
  double? _selectedLng;

  // ✅ Variables Autocomplete
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadWorkAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWorkAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.userId;
      if (userId != null) {
        // Fallback or legacy string
        String address = prefs.getString('work_address_$userId') ?? '';
        
        // V2 JSON string containing coordinates
        String workDataStr = prefs.getString('work_address_data_$userId') ?? '';
        
        if (workDataStr.isNotEmpty) {
           final Map<String, dynamic> data = jsonDecode(workDataStr);
           address = data['address'] ?? '';
           _savedLat = data['latitude'];
           _savedLng = data['longitude'];
        }

        if (address.isNotEmpty && mounted) {
          setState(() {
            _savedAddress = address;
            _addressController.text = address;
          });
        }
      }
    } catch (e) {
      print("❌ Erreur chargement adresse: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveWorkAddress() async {
    if (_addressController.text.trim().isEmpty) {
      SnackBarHelper.showWarning(context, "Veuillez entrer une adresse");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.userId;
      if (userId != null) {
        await prefs.setString('work_address_$userId', _addressController.text.trim());
        
        // Save full map if we have it
        if (_selectedLat != null && _selectedLng != null) {
          await prefs.setString('work_address_data_$userId', jsonEncode({
            'address': _addressController.text.trim(),
            'latitude': _selectedLat,
            'longitude': _selectedLng,
          }));
        }
      }

      setState(() {
        _savedAddress = _addressController.text;
        _savedLat = _selectedLat;
        _savedLng = _selectedLng;
        _isSaving = false;
        _showResults = false;
        _searchResults = [];
      });

      _searchFocusNode.unfocus();

      if (mounted) {
        SnackBarHelper.showSuccess(context, "Adresse enregistrée avec succès");
      }
    } catch (e) {
      print("❌ Erreur sauvegarde: $e");
      setState(() => _isSaving = false);
      if (mounted) {
        SnackBarHelper.showError(context, "Erreur lors de la sauvegarde: $e");
      }
    }
  }

  Future<void> _deleteWorkAddress() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer l'adresse ?"),
        content: const Text("Voulez-vous vraiment retirer votre adresse de travail actuelle ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.userId;
      if (userId != null) {
        await prefs.remove('work_address_$userId');
        await prefs.remove('work_address_data_$userId');
      }

      setState(() {
        _savedAddress = null;
        _savedLat = null;
        _savedLng = null;
        _addressController.clear();
        _isSaving = false;
      });

      if (mounted) {
        SnackBarHelper.showSuccess(context, "Adresse supprimée");
      }
    } catch (e) {
      print("❌ Erreur suppression adresse: $e");
      setState(() => _isSaving = false);
    }
  }

  void _onAddressCardTapped() {
    if (_savedAddress != null && _savedLat != null && _savedLng != null) {
      Navigator.pop(context, {
        'address': _savedAddress,
        'latitude': _savedLat,
        'longitude': _savedLng,
        'name': 'Lieu de Travail',
      });
    } else if (_savedAddress != null) {
        SnackBarHelper.showWarning(context, "Veuillez d'abord chercher et valider votre adresse depuis la barre pour avoir les coordonnées GPS exactes.");
    }
  }

  // ✅ RECHERCHE AVEC DEBOUNCING
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
    if (query.trim().isEmpty) return;

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
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    setState(() {
      String fullAddress = "${place['main_text']}, ${place['secondary_text']}";
      _addressController.text = fullAddress;
      _selectedLat = double.tryParse(place['lat'].toString());
      _selectedLng = double.tryParse(place['lng'].toString());
      _showResults = false;
      _searchResults = [];
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Adresse Travail", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ EN-TÊTE
              const Row(
                children: [
                  Icon(Icons.business_center, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text(
                    "Où travaillez-vous ?",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Enregistrez votre lieu de travail pour pouvoir commander un taxi plus rapidement.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // ✅ CHAMPS DE RECHERCHE
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _addressController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _debounceTimer?.cancel();
                    _searchPlaces(value);
                  },
                  decoration: InputDecoration(
                    hintText: "Rechercher une adresse...",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _isSearching
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                        : (_addressController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _addressController.clear();
                        _onSearchChanged('');
                      },
                    )
                        : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              // ✅ RÉSULTATS AUTOLOGGED
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
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.location_on, color: AppColors.primary),
                        ),
                        title: Text(place['main_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(place['secondary_text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectPlace(place),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 32),

              // ✅ BOUTON ENREGISTRER
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveWorkAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "ENREGISTRER L'ADRESSE",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),

              // ✅ ADRESSE ACTUELLE INFO
              if (_savedAddress != null) ...[
                const SizedBox(height: 40),
                const Text(
                  "ADRESSE ENREGISTRÉE (Cliquez pour y aller)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _onAddressCardTapped,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.business_center, color: Colors.green.shade600),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Lieu de Travail", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                _savedAddress!,
                                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Column(
                            children: [
                              const Icon(Icons.directions_car, color: AppColors.primary),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: _deleteWorkAddress,
                                tooltip: "Supprimer",
                              ),
                            ]
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}