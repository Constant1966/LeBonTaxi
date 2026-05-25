class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final double discountPercentage;
  final int durationDays;
  final bool isActive;
  final int displayOrder;
  final List<String> features;
  final int? maxTripsPerDay;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.discountPercentage,
    required this.durationDays,
    this.isActive = true,
    this.displayOrder = 0,
    this.features = const [],
    this.maxTripsPerDay,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    // Parser les features (JSONB → List<String>)
    List<String> featuresList = [];
    if (map['features'] is List) {
      featuresList = (map['features'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return SubscriptionPlan(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      currency: map['currency']?.toString() ?? 'HTG',
      discountPercentage: (map['discount_percentage'] is num) ? (map['discount_percentage'] as num).toDouble() : 0.0,
      durationDays: (map['duration_days'] is num) ? (map['duration_days'] as num).toInt() : 30,
      isActive: map['is_active'] == true,
      displayOrder: (map['display_order'] is num) ? (map['display_order'] as num).toInt() : 0,
      features: featuresList,
      maxTripsPerDay: (map['max_trips_per_day'] is num) ? (map['max_trips_per_day'] as num).toInt() : null,
    );
  }

  /// Convertir en Map pour envoi à Supabase (utile pour le web panel)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'discount_percentage': discountPercentage,
      'duration_days': durationDays,
      'is_active': isActive,
      'display_order': displayOrder,
      'features': features,
      'max_trips_per_day': maxTripsPerDay,
    };
  }
}
