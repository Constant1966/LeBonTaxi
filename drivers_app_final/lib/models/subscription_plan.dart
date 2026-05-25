/// Modèle pour un plan d'abonnement (récupéré depuis Supabase)
class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int durationDays;
  final double discountPercentage;
  final List<String> features;
  final bool isActive;
  final String targetAudience; // 'user', 'driver', 'both'
  final DateTime? createdAt;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationDays,
    required this.discountPercentage,
    this.features = const [],
    this.isActive = true,
    this.targetAudience = 'both',
    this.createdAt,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    // Parse features — peut être un JSON array ou une string
    List<String> parseFeatures(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        // Essayer de parser comme liste séparée par virgules
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return SubscriptionPlan(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Plan',
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      durationDays: (map['duration_days'] as num?)?.toInt() ?? 30,
      discountPercentage: (map['discount_percentage'] as num?)?.toDouble() ?? 0.0,
      features: parseFeatures(map['features']),
      isActive: map['is_active'] as bool? ?? true,
      targetAudience: map['target_audience']?.toString() ?? 'both',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_days': durationDays,
      'discount_percentage': discountPercentage,
      'features': features,
      'is_active': isActive,
      'target_audience': targetAudience,
    };
  }

  String get durationLabel {
    if (durationDays == 7) return '1 Semaine';
    if (durationDays == 30) return '1 Mois';
    if (durationDays == 90) return '3 Mois';
    if (durationDays == 180) return '6 Mois';
    if (durationDays == 365) return '1 An';
    return '$durationDays jours';
  }

  String get priceLabel => '${price.toStringAsFixed(0)} HTG';

  String get discountLabel => '${discountPercentage.toStringAsFixed(0)}%';

  @override
  String toString() =>
      'SubscriptionPlan(id: $id, name: $name, price: $price, duration: $durationDays days, discount: $discountPercentage%)';
}

/// Modèle pour un abonnement actif/historique d'un chauffeur
class DriverSubscription {
  final String id;
  final String driverId;
  final String planId;
  final String? planName;
  final double? planPrice;
  final double? discountPercentage;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'active', 'expired', 'cancelled'
  final DateTime? createdAt;

  DriverSubscription({
    required this.id,
    required this.driverId,
    required this.planId,
    this.planName,
    this.planPrice,
    this.discountPercentage,
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    this.createdAt,
  });

  factory DriverSubscription.fromMap(Map<String, dynamic> map) {
    return DriverSubscription(
      id: map['id']?.toString() ?? '',
      driverId: map['user_id']?.toString() ?? map['driver_id']?.toString() ?? '',
      planId: map['plan_id']?.toString() ?? '',
      planName: map['plan_name']?.toString() ?? map['subscription_plans']?['name']?.toString(),
      planPrice: (map['plan_price'] as num?)?.toDouble() ??
          (map['subscription_plans']?['price'] as num?)?.toDouble(),
      discountPercentage: (map['discount_percentage'] as num?)?.toDouble() ??
          (map['subscription_plans']?['discount_percentage'] as num?)?.toDouble(),
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['end_date']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'active',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  bool get isActive {
    return status == 'active' && DateTime.now().isBefore(endDate);
  }

  int get daysRemaining {
    final remaining = endDate.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  double get progressRatio {
    final total = endDate.difference(startDate).inDays;
    if (total <= 0) return 0.0;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get statusLabel {
    if (isActive) return 'Actif';
    if (status == 'cancelled') return 'Annulé';
    return 'Expiré';
  }

  @override
  String toString() =>
      'DriverSubscription(id: $id, plan: $planName, status: $status, expires: $endDate)';
}
