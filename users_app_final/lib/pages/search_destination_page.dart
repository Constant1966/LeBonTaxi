import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:users_app/global/global_var_supabase.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/osm_map_service.dart';
import 'package:users_app/services/osrm_routing_service.dart';
import 'package:users_app/services/geocoding_service.dart';
import 'package:users_app/services/driver_service.dart';
import 'package:users_app/services/poi_service.dart';
import 'package:users_app/methods/fare_calculator.dart';

class SearchDestinationPage extends StatefulWidget {
  const SearchDestinationPage({super.key});

  @override
  State<SearchDestinationPage> createState() => _SearchDestinationPageState();
}

class _SearchDestinationPageState extends State<SearchDestinationPage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Chauffeurs disponibles
  List<Map<String, dynamic>> _availableDrivers = [];
  Timer? _driverUpdateTimer;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  // ✅ Debouncing
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  // Position de départ
  LatLng? _pickupLocation;
  String _pickupAddress = "";

  // Destination sélectionnée
  LatLng? _destinationLocation;
  String _destinationAddress = "";

  // Route
  List<LatLng> _routePoints = [];
  String _distance = "";
  String _duration = "";
  String _fareAmount = "";

  // Marqueurs et polylines
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];

  // ✅ Sections UI
  bool _showRecents = true;
  bool _showPopular = true;
  List<Map<String, dynamic>> _recentSearches = [];

  // ✅ POI
  String? _selectedPOICategory;
  List<POIResult> _poiResults = [];
  bool _isLoadingPOI = false;

  // ✅ Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // ✅ Trafic
  TrafficEstimation _trafficEstimation = TrafficEstimation.light;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _initializePickupLocation();
    _loadNearbyDrivers();
    _loadRecentSearches();
    _trafficEstimation = OSRMRoutingService.getTrafficEstimation();

    _driverUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadNearbyDrivers(),
    );

    // Ouvrir le clavier automatiquement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _driverUpdateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _initializePickupLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _pickupLocation = LatLng(position.latitude, position.longitude);
      _pickupAddress = pickUpAddress ?? "Votre position";

      if (_pickupLocation != null) {
        _mapController.move(_pickupLocation!, 14.0);
        _addPickupMarker();
      }
    } catch (e) {
      print("❌ Erreur position: $e");
      _pickupLocation = haitiInitialPosition;
      _pickupAddress = "Port-au-Prince, Haïti";
      _addPickupMarker();
    }
  }

  Future<void> _loadNearbyDrivers() async {
    if (_pickupLocation == null) return;

    try {
      final drivers = await DriverService.getNearbyDrivers(
        userLocation: _pickupLocation!,
        radiusMeters: 5000,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _availableDrivers = drivers;
          _updateDriverMarkers();
        });
      }
    } catch (e) {
      print('❌ Erreur chargement chauffeurs: $e');
    }
  }

  Future<void> _loadRecentSearches() async {
    final recents = await GeocodingService.getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = recents);
    }
  }

  void _updateDriverMarkers() {
    _markers.removeWhere((marker) {
      return marker.point != _pickupLocation &&
          marker.point != _destinationLocation;
    });

    for (var driver in _availableDrivers) {
      final lat =
          (driver['current_latitude'] ?? driver['latitude']) as double?;
      final lng =
          (driver['current_longitude'] ?? driver['longitude']) as double?;

      if (lat != null && lng != null) {
        _markers.add(_createDriverMarker(lat, lng, driver));
      }
    }
  }

  Marker _createDriverMarker(
      double lat, double lng, Map<String, dynamic> driver) {
    return Marker(
      point: LatLng(lat, lng),
      width: 50,
      height: 50,
      child: GestureDetector(
        onTap: () => _showDriverInfo(driver),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                driver['vehicle_type'] == 'moto'
                    ? Icons.two_wheeler
                    : Icons.directions_car,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${driver['rating'] ?? 5.0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverInfo(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: driver['photo'] != null
                      ? NetworkImage(driver['photo'] as String)
                      : null,
                  child: driver['photo'] == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver['name'] as String? ?? 'Chauffeur',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${driver['rating'] ?? 5.0}'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (driver['car_model'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      driver['vehicle_type'] == 'moto'
                          ? Icons.two_wheeler
                          : Icons.directions_car,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              driver['car_model'] as String? ?? 'Véhicule',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (driver['car_color'] != null)
                            Text(
                              driver['car_color'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${(((driver['distance_meters'] as num?) ?? 0) / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _addPickupMarker() {
    if (_pickupLocation == null) return;

    _markers.add(OSMMapService.createPickupMarker(_pickupLocation!));
    setState(() {});
  }

  void _addDestinationMarker() {
    if (_destinationLocation == null) return;

    _markers.removeWhere((marker) =>
        marker.point.latitude == _destinationLocation!.latitude &&
        marker.point.longitude == _destinationLocation!.longitude);

    _markers.add(OSMMapService.createDropoffMarker(_destinationLocation!));
    setState(() {});
  }

  // ✅ RECHERCHE AVEC DEBOUNCING
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
        _showRecents = true;
        _showPopular = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showRecents = false;
      _showPopular = false;
    });

    _debounceTimer = Timer(_debounceDuration, () {
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
        _showSnackBar("Erreur de recherche", isError: true);
      }
    }
  }

  Future<void> _selectDestination(Map<String, dynamic> place) async {
    // Sauvegarder dans les récents
    await GeocodingService.saveRecentSearch(place);

    setState(() {
      _destinationLocation = LatLng(place['lat'], place['lng']);
      _destinationAddress = place['name'] ?? place['main_text'] ?? 'Destination';
      _showResults = false;
      _showRecents = false;
      _showPopular = false;
      _searchController.text = place['main_text'] ?? '';
    });

    _searchFocusNode.unfocus();
    _addDestinationMarker();

    if (_pickupLocation != null && _destinationLocation != null) {
      await _calculateRoute();
    }

    if (_pickupLocation != null && _destinationLocation != null) {
      OSMMapService.animateToBounds(
        _mapController,
        [_pickupLocation!, _destinationLocation!],
        padding: const EdgeInsets.all(70),
      );
    }
  }

  Future<void> _calculateRoute() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    try {
      final route = await OSRMRoutingService.getRoute(
        _pickupLocation!,
        _destinationLocation!,
      );

      if (route == null) {
        _showSnackBar("Impossible de calculer l'itinéraire", isError: true);
        return;
      }

      setState(() {
        _routePoints = route.geometry;
        _distance = route.distanceText;
        _duration = route.trafficAdjustedDurationText;

        // ✅ Calcul dynamique avec tarifs Supabase + réduction abonnement
        final distanceKm = route.distance / 1000;
        final fare = FareCalculator.calculate(
          distanceKm: distanceKm,
          discountPercentage: currentUserDiscount,
          referralDiscountValue: currentReferralDiscount,
          referralDiscountType: currentReferralDiscountType,
        );
        _fareAmount = "$fare HTG";
      });

      _polylines.clear();
      _polylines.add(
        OSMMapService.createRoutePolyline(
          _routePoints,
          color: AppColors.primary,
        ),
      );

      setState(() {});

      if (route.isFallback) {
        _showSnackBar("⚠️ Itinéraire approximatif (connexion limitée)", isInfo: true);
      }
    } catch (e) {
      print("❌ Erreur calcul route: $e");
      _showSnackBar("Erreur: $e", isError: true);
    }
  }

  // ✅ POI
  Future<void> _loadPOI(String categoryKey) async {
    if (_pickupLocation == null) return;

    setState(() {
      _selectedPOICategory =
          _selectedPOICategory == categoryKey ? null : categoryKey;
      _isLoadingPOI = true;
      _poiResults = [];
    });

    if (_selectedPOICategory == null) {
      setState(() => _isLoadingPOI = false);
      return;
    }

    try {
      final results = await POIService.searchNearby(
        center: _pickupLocation!,
        categoryKey: categoryKey,
        radiusMeters: 5000,
      );

      if (mounted) {
        setState(() {
          _poiResults = results;
          _isLoadingPOI = false;

          if (results.isNotEmpty) {
            _showResults = false;
            _showRecents = false;
            _showPopular = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPOI = false);
        _showSnackBar("Erreur chargement POI", isError: true);
      }
    }
  }

  void _selectPOI(POIResult poi) {
    _selectDestination({
      'main_text': poi.name,
      'secondary_text': poi.address.isNotEmpty ? poi.address : poi.categoryLabel,
      'lat': poi.lat,
      'lng': poi.lng,
      'name': poi.name,
      'category': poi.category,
    });
  }

  void _confirmDestination() {
    if (_destinationLocation == null) {
      _showSnackBar("Veuillez sélectionner une destination", isError: true);
      return;
    }

    Navigator.pop(context, {
      'pickup_location': _pickupLocation,
      'pickup_address': _pickupAddress,
      'destination_location': _destinationLocation,
      'destination_address': _destinationAddress,
      'distance': _distance,
      'duration': _duration,
      'fare_amount': _fareAmount,
      'route_points': _routePoints,
    });
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isInfo = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : (isInfo ? AppColors.info : AppColors.success),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ Carte
          FlutterMap(
            mapController: _mapController,
            options: OSMMapService.createMapOptions(
              center: _pickupLocation ?? haitiInitialPosition,
              zoom: 14.0,
            ),
            children: [
              OSMMapService.createTileLayer(),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: [
                ..._markers,
                // POI markers
                ..._poiResults.map((poi) => Marker(
                      point: poi.position,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _selectPOI(poi),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.getPOIColor(poi.category),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.getPOIColor(poi.category)
                                    .withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              poi.categoryIcon,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    )),
              ]),
            ],
          ),

          // ✅ Barre de recherche + résultats
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // ✅ Search bar
                  _buildSearchBar(),

                  // ✅ Traffic badge
                  if (!_showResults && _destinationLocation == null)
                    _buildTrafficBadge(),

                  // ✅ Drivers badge
                  if (_availableDrivers.isNotEmpty &&
                      !_showResults &&
                      _destinationLocation == null)
                    _buildDriversBadge(),

                  // ✅ POI chips
                  if (!_showResults && _destinationLocation == null)
                    _buildPOIChips(),

                  // ✅ POI results
                  if (_poiResults.isNotEmpty && _selectedPOICategory != null)
                    _buildPOIResults(),

                  // ✅ Search results
                  if (_showResults) _buildSearchResults(),

                  // ✅ Recent searches
                  if (_showRecents &&
                      _recentSearches.isNotEmpty &&
                      !_showResults &&
                      _destinationLocation == null)
                    _buildRecentSearches(),

                  // ✅ Popular destinations
                  if (_showPopular &&
                      !_showResults &&
                      _destinationLocation == null)
                    _buildPopularDestinations(),
                ],
              ),
            ),
          ),

          // ✅ Bottom panel (route info)
          if (_destinationLocation != null && _distance.isNotEmpty)
            _buildRouteInfoPanel(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ✅ WIDGETS
  // ═══════════════════════════════════════════

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Où allez-vous ?",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounceTimer?.cancel();
                _searchPlaces(value);
              },
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          if (_searchController.text.isNotEmpty && !_isSearching)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
              onPressed: () {
                _searchController.clear();
                _debounceTimer?.cancel();
                setState(() {
                  _searchResults = [];
                  _showResults = false;
                  _showRecents = true;
                  _showPopular = true;
                  _selectedPOICategory = null;
                  _poiResults = [];
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrafficBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Text(_trafficEstimation.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            'Trafic ${_trafficEstimation.label.toLowerCase()}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _trafficEstimation == TrafficEstimation.heavy
                  ? AppColors.error
                  : (_trafficEstimation == TrafficEstimation.moderate
                      ? AppColors.warning
                      : AppColors.success),
            ),
          ),
          const Spacer(),
          if (_availableDrivers.isNotEmpty)
            Text(
              '${_availableDrivers.length} taxi${_availableDrivers.length > 1 ? 's' : ''} proches',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildDriversBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_taxi, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            '${_availableDrivers.length} chauffeur${_availableDrivers.length > 1 ? 's' : ''} disponible${_availableDrivers.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPOIChips() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: POIService.categories.entries.map((entry) {
          final isSelected = _selectedPOICategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _loadPOI(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.getPOIColor(entry.key)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.getPOIColor(entry.key)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.value.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      entry.value.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected && _isLoadingPOI) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPOIResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _poiResults.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final poi = _poiResults[index];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getPOIColor(poi.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(poi.categoryIcon, style: const TextStyle(fontSize: 18))),
            ),
            title: Text(poi.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: poi.address.isNotEmpty
                ? Text(poi.address,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                : null,
            trailing: Text(
              poi.distanceText,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            onTap: () => _selectPOI(poi),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final place = _searchResults[index];
          final category = place['category'] ?? 'place';

          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getPOIColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getCategoryIcon(category),
                color: AppColors.getPOIColor(category),
                size: 20,
              ),
            ),
            title: Text(
              place['main_text'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              place['secondary_text'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectDestination(place),
          );
        },
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Recherches récentes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await GeocodingService.clearRecentSearches();
                    setState(() => _recentSearches = []);
                  },
                  child: const Text('Effacer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          ...(_recentSearches.take(5).map((place) => ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
                title: Text(
                  place['main_text'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: place['secondary_text'] != null
                    ? Text(
                        place['secondary_text'],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => _selectDestination(place),
              ))),
        ],
      ),
    );
  }

  Widget _buildPopularDestinations() {
    final popular = GeocodingService.getPopularDestinations();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.trending_up, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Destinations populaires',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...popular.map((place) => ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      place['icon'] ?? '📍',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                title: Text(
                  place['main_text'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  place['secondary_text'] ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                onTap: () => _selectDestination(place),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRouteInfoPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Addresses
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(width: 2, height: 36, color: Colors.grey.shade300),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickupAddress,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _destinationAddress.split(',').first,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Trip info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoChip(Icons.route, "Distance", _distance),
                      Container(width: 1, height: 36, color: Colors.grey.shade300),
                      _buildInfoChip(Icons.access_time, "Durée", _duration),
                      Container(width: 1, height: 36, color: Colors.grey.shade300),
                      _buildInfoChip(Icons.payments, "Tarif", _fareAmount),
                    ],
                  ),
                ),

                // Traffic badge
                if (_trafficEstimation != TrafficEstimation.light)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_trafficEstimation == TrafficEstimation.heavy
                              ? AppColors.error
                              : AppColors.warning)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_trafficEstimation.emoji),
                        const SizedBox(width: 4),
                        Text(
                          'Trafic ${_trafficEstimation.label.toLowerCase()} — durée ajustée',
                          style: TextStyle(
                            fontSize: 12,
                            color: _trafficEstimation == TrafficEstimation.heavy
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _confirmDestination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "CONFIRMER LA DESTINATION",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'hospital':
        return Icons.local_hospital;
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'airport':
        return Icons.flight;
      case 'education':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_bag;
      case 'landmark':
        return Icons.account_balance;
      default:
        return Icons.location_on;
    }
  }
}