import 'package:latlong2/latlong.dart';

/// Modèle pour les détails d'une course (adapté pour Supabase + OSM)
class TripDetails {
  String? tripID;
  LatLng? pickUpLatLng;
  String? pickupAddress;
  LatLng? dropOffLatLng;
  String? dropOffAddress;
  String? userName;
  String? userPhone;
  String? userPhoto;

  TripDetails({
    this.tripID,
    this.pickUpLatLng,
    this.pickupAddress,
    this.dropOffLatLng,
    this.dropOffAddress,
    this.userName,
    this.userPhone,
    this.userPhoto,
  });

  /// Crée un TripDetails depuis les données Supabase
  factory TripDetails.fromSupabase(Map<String, dynamic> data) {
    return TripDetails(
      tripID: data['trip_id']?.toString(),
      pickUpLatLng: data['pickup_latitude'] != null && data['pickup_longitude'] != null
          ? LatLng(
              (data['pickup_latitude'] as num).toDouble(),
              (data['pickup_longitude'] as num).toDouble(),
            )
          : null,
      pickupAddress: data['pickup_address']?.toString(),
      dropOffLatLng: data['dropoff_latitude'] != null && data['dropoff_longitude'] != null
          ? LatLng(
              (data['dropoff_latitude'] as num).toDouble(),
              (data['dropoff_longitude'] as num).toDouble(),
            )
          : null,
      dropOffAddress: data['dropoff_address']?.toString(),
      userName: data['user_name']?.toString(),
      userPhone: data['user_phone']?.toString(),
      userPhoto: data['user_photo']?.toString(),
    );
  }

  /// Convertit en Map pour Supabase
  Map<String, dynamic> toMap() {
    return {
      if (tripID != null) 'trip_id': tripID,
      if (pickUpLatLng != null) 'pickup_latitude': pickUpLatLng!.latitude,
      if (pickUpLatLng != null) 'pickup_longitude': pickUpLatLng!.longitude,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      if (dropOffLatLng != null) 'dropoff_latitude': dropOffLatLng!.latitude,
      if (dropOffLatLng != null) 'dropoff_longitude': dropOffLatLng!.longitude,
      if (dropOffAddress != null) 'dropoff_address': dropOffAddress,
      if (userName != null) 'user_name': userName,
      if (userPhone != null) 'user_phone': userPhone,
      if (userPhoto != null) 'user_photo': userPhoto,
    };
  }

  @override
  String toString() {
    return 'TripDetails('
        'tripID: $tripID, '
        'pickUpLatLng: $pickUpLatLng, '
        'pickupAddress: $pickupAddress, '
        'dropOffLatLng: $dropOffLatLng, '
        'dropOffAddress: $dropOffAddress, '
        'userName: $userName, '
        'userPhone: $userPhone)';
  }
}