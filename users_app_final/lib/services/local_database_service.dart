import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service SQLite pour le cache local — démarrage rapide et mode hors-ligne
class LocalDatabaseService {
  static Database? _database;
  static const String _dbName = 'lebontaxi_user.db';
  static const int _dbVersion = 1;

  // ============================================================
  // INITIALISATION
  // ============================================================

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Table profil utilisateur
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT,
        photo TEXT,
        subscription_plan_id TEXT,
        subscription_end_date TEXT,
        block_status TEXT DEFAULT 'no',
        last_synced TEXT
      )
    ''');

    // Table courses en cache
    await db.execute('''
      CREATE TABLE cached_trips (
        trip_id TEXT PRIMARY KEY,
        status TEXT,
        pickup_address TEXT,
        dropoff_address TEXT,
        pickup_lat REAL,
        pickup_lng REAL,
        dropoff_lat REAL,
        dropoff_lng REAL,
        driver_name TEXT,
        driver_phone TEXT,
        fare_amount REAL,
        distance TEXT,
        duration TEXT,
        payment_method TEXT,
        tip REAL DEFAULT 0,
        created_at TEXT,
        completed_at TEXT,
        cancelled_at TEXT,
        driver_id TEXT,
        last_synced TEXT
      )
    ''');

    // Table messages admin en cache
    await db.execute('''
      CREATE TABLE cached_admin_messages (
        id TEXT PRIMARY KEY,
        title TEXT,
        message TEXT,
        recipient_type TEXT,
        sender_admin_email TEXT,
        created_at TEXT,
        is_read INTEGER DEFAULT 0,
        last_synced TEXT
      )
    ''');

    // Table lieux favoris en cache
    await db.execute('''
      CREATE TABLE cached_favorite_locations (
        id TEXT PRIMARY KEY,
        name TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        last_synced TEXT
      )
    ''');

    // Table paramètres app (tarification, etc.)
    await db.execute('''
      CREATE TABLE cached_app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        last_synced TEXT
      )
    ''');

    print('✅ Base de données SQLite utilisateur créée');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations futures
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {
        'id': profile['id'] ?? '',
        'name': profile['name'] ?? '',
        'email': profile['email'] ?? '',
        'phone': profile['phone'] ?? '',
        'photo': profile['photo'] ?? '',
        'subscription_plan_id': profile['subscription_plan_id'] ?? '',
        'subscription_end_date': profile['subscription_end_date'] ?? '',
        'block_status': profile['block_status'] ?? 'no',
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('✅ Profil utilisateur sauvegardé en local');
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final results = await db.query('user_profile', limit: 1);
    if (results.isEmpty) return null;
    return results.first;
  }

  // ============================================================
  // CACHED TRIPS
  // ============================================================

  static Future<void> saveTrips(List<Map<String, dynamic>> trips) async {
    final db = await database;
    final batch = db.batch();

    for (var trip in trips) {
      batch.insert(
        'cached_trips',
        {
          'trip_id': trip['trip_id'] ?? trip['id'] ?? '',
          'status': trip['status'] ?? '',
          'pickup_address': trip['pickup_address'] ?? '',
          'dropoff_address': trip['dropoff_address'] ?? '',
          'pickup_lat': trip['pickup_latitude'],
          'pickup_lng': trip['pickup_longitude'],
          'dropoff_lat': trip['dropoff_latitude'],
          'dropoff_lng': trip['dropoff_longitude'],
          'driver_name': trip['driver_name'] ?? trip['drivers']?['name'] ?? '',
          'driver_phone': trip['driver_phone'] ?? trip['drivers']?['phone'] ?? '',
          'fare_amount': trip['fare_amount'],
          'distance': trip['distance'] ?? '',
          'duration': trip['duration'] ?? '',
          'payment_method': trip['payment_method'] ?? 'cash',
          'tip': trip['tip'] ?? 0,
          'created_at': trip['created_at'] ?? '',
          'completed_at': trip['completed_at'] ?? '',
          'cancelled_at': trip['cancelled_at'] ?? '',
          'driver_id': trip['driver_id'] ?? '',
          'last_synced': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ ${trips.length} courses sauvegardées en local');
  }

  static Future<List<Map<String, dynamic>>> getCachedTrips({
    String? status,
    int limit = 50,
  }) async {
    final db = await database;

    if (status != null) {
      return await db.query(
        'cached_trips',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }

    return await db.query(
      'cached_trips',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  static Future<int> getTripsCount({String? status}) async {
    final db = await database;
    final query = status != null
        ? "SELECT COUNT(*) as count FROM cached_trips WHERE status = '$status'"
        : "SELECT COUNT(*) as count FROM cached_trips";
    final result = await db.rawQuery(query);
    return result.first['count'] as int? ?? 0;
  }

  // ============================================================
  // ADMIN MESSAGES
  // ============================================================

  static Future<void> saveAdminMessages(List<Map<String, dynamic>> messages) async {
    final db = await database;
    final batch = db.batch();

    for (var msg in messages) {
      // Conserver l'état is_read existant
      final existing = await db.query(
        'cached_admin_messages',
        where: 'id = ?',
        whereArgs: [msg['id'].toString()],
        limit: 1,
      );
      final isRead = existing.isNotEmpty ? (existing.first['is_read'] as int? ?? 0) : 0;

      batch.insert(
        'cached_admin_messages',
        {
          'id': msg['id'].toString(),
          'title': msg['title'] ?? '',
          'message': msg['message'] ?? '',
          'recipient_type': msg['recipient_type'] ?? '',
          'sender_admin_email': msg['sender_admin_email'] ?? '',
          'created_at': msg['created_at'] ?? '',
          'is_read': isRead,
          'last_synced': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ ${messages.length} messages admin sauvegardés en local');
  }

  static Future<List<Map<String, dynamic>>> getCachedAdminMessages() async {
    final db = await database;
    return await db.query(
      'cached_admin_messages',
      orderBy: 'created_at DESC',
    );
  }

  static Future<int> getUnreadMessageCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cached_admin_messages WHERE is_read = 0",
    );
    return result.first['count'] as int? ?? 0;
  }

  static Future<void> markMessageRead(String messageId) async {
    final db = await database;
    await db.update(
      'cached_admin_messages',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  static Future<void> markAllMessagesRead() async {
    final db = await database;
    await db.update('cached_admin_messages', {'is_read': 1});
  }

  // ============================================================
  // FAVORITE LOCATIONS
  // ============================================================

  static Future<void> saveFavoriteLocations(List<Map<String, dynamic>> locations) async {
    final db = await database;
    final batch = db.batch();

    for (var loc in locations) {
      batch.insert(
        'cached_favorite_locations',
        {
          'id': loc['id']?.toString() ?? '',
          'name': loc['name'] ?? '',
          'address': loc['address'] ?? '',
          'latitude': loc['latitude'],
          'longitude': loc['longitude'],
          'last_synced': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedFavoriteLocations() async {
    final db = await database;
    return await db.query('cached_favorite_locations');
  }

  // ============================================================
  // APP SETTINGS (Tarification, etc.)
  // ============================================================

  static Future<void> saveAppSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'cached_app_settings',
      {
        'key': key,
        'value': value,
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getAppSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'cached_app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  /// Sauvegarder les tarifs dans le cache
  static Future<void> cachePricingSettings({
    required double baseFare,
    required double perKmRate,
    required double minimumFare,
  }) async {
    await saveAppSetting('base_fare', baseFare.toString());
    await saveAppSetting('per_km_rate', perKmRate.toString());
    await saveAppSetting('minimum_fare', minimumFare.toString());
    print('✅ Tarifs sauvegardés en cache SQLite');
  }

  /// Charger les tarifs depuis le cache
  static Future<Map<String, double>?> getCachedPricingSettings() async {
    final baseFare = await getAppSetting('base_fare');
    final perKmRate = await getAppSetting('per_km_rate');
    final minimumFare = await getAppSetting('minimum_fare');

    if (baseFare == null || perKmRate == null || minimumFare == null) return null;

    return {
      'base_fare': double.tryParse(baseFare) ?? 0,
      'per_km_rate': double.tryParse(perKmRate) ?? 0,
      'minimum_fare': double.tryParse(minimumFare) ?? 0,
    };
  }

  // ============================================================
  // NETTOYAGE
  // ============================================================

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('user_profile');
    await db.delete('cached_trips');
    await db.delete('cached_admin_messages');
    await db.delete('cached_favorite_locations');
    await db.delete('cached_app_settings');
    print('🗑️ Base de données locale vidée');
  }

  static Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
