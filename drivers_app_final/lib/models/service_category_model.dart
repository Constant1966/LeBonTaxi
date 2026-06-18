// lib/models/service_category_model.dart

class ServiceCategory {
  final String id;
  final String name;
  final String slug; // 'standard' | 'luxury' | 'event' | 'moving'
  final String? description;
  final String? icon;
  final bool isActive;
  final List<String> vehicleTypes;
  final double baseFareMultiplier;
  final DateTime createdAt;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    required this.isActive,
    required this.vehicleTypes,
    required this.baseFareMultiplier,
    required this.createdAt,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map) {
    return ServiceCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      vehicleTypes: List<String>.from(map['vehicle_types'] as List? ?? []),
      baseFareMultiplier: (map['base_fare_multiplier'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'is_active': isActive,
      'vehicle_types': vehicleTypes,
      'base_fare_multiplier': baseFareMultiplier,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isLuxury => slug == 'luxury';
  bool get isEvent => slug == 'event';
  bool get isMoving => slug == 'moving';
  bool get isStandard => slug == 'standard';

  String get fareSummary {
    if (baseFareMultiplier == 1.0) return 'Tarif standard';
    return 'x${baseFareMultiplier.toStringAsFixed(1)} tarif standard';
  }
}
