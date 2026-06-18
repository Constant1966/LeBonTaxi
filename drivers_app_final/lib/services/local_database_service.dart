import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service SQLite pour le cache local et le mode hors-ligne
class LocalDatabaseService {
  static Database? _database;
  static const String _dbName = 'lebontaxi_driver.db';
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
    // Table profil chauffeur
    await db.execute('''
      CREATE TABLE driver_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT,
        photo TEXT,
        car_model TEXT,
        car_color TEXT,
        car_number TEXT,
        car_year TEXT,
        car_front_photo TEXT,
        car_back_photo TEXT,
        car_side_photo TEXT,
        fcm_token TEXT,
        is_online INTEGER DEFAULT 0,
        is_available INTEGER DEFAULT 0,
        verified INTEGER DEFAULT 0,
        profile_completed INTEGER DEFAULT 0,
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
        user_name TEXT,
        user_phone TEXT,
        fare_amount REAL,
        distance_km REAL,
        duration_minutes INTEGER,
        driver_id TEXT,
        created_at TEXT,
        accepted_at TEXT,
        completed_at TEXT,
        cancelled_at TEXT,
        cancel_reason TEXT,
        last_synced TEXT
      )
    ''');

    // Table gains en cache
    await db.execute('''
      CREATE TABLE cached_earnings (
        id TEXT PRIMARY KEY,
        driver_id TEXT,
        trip_id TEXT,
        amount REAL,
        created_at TEXT,
        last_synced TEXT
      )
    ''');

    // File d'attente des actions hors-ligne
    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // Table paramètres app (tarification, onboarding, etc.)
    await db.execute('''
      CREATE TABLE cached_app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        last_synced TEXT
      )
    ''');

    print('✅ Base de données SQLite créée');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations futures ici
  }

  // ============================================================
  // DRIVER PROFILE
  // ============================================================

  static Future<void> saveDriverProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'driver_profile',
      {
        'id': profile['id'] ?? '',
        'name': profile['name'] ?? '',
        'email': profile['email'] ?? '',
        'phone': profile['phone'] ?? '',
        'photo': profile['photo'] ?? '',
        'car_model': profile['car_model'] ?? '',
        'car_color': profile['car_color'] ?? '',
        'car_number': profile['car_number'] ?? '',
        'car_year': profile['car_year'] ?? '',
        'car_front_photo': profile['car_front_photo'] ?? '',
        'car_back_photo': profile['car_back_photo'] ?? '',
        'car_side_photo': profile['car_side_photo'] ?? '',
        'fcm_token': profile['fcm_token'] ?? '',
        'is_online': (profile['is_online'] == true) ? 1 : 0,
        'is_available': (profile['is_available'] == true) ? 1 : 0,
        'verified': (profile['verified'] == true) ? 1 : 0,
        'profile_completed': (profile['profile_completed'] == true) ? 1 : 0,
        'block_status': profile['block_status'] ?? 'no',
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('✅ Profil sauvegardé en local');
  }

  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    final db = await database;
    final results = await db.query(
      'driver_profile',
      where: 'id = ?',
      whereArgs: [driverId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return {
      ...row,
      'is_online': row['is_online'] == 1,
      'is_available': row['is_available'] == 1,
      'verified': row['verified'] == 1,
      'profile_completed': row['profile_completed'] == 1,
    };
  }

  static Future<Map<String, dynamic>?> getAnyDriverProfile() async {
    final db = await database;
    final results = await db.query('driver_profile', limit: 1);
    if (results.isEmpty) return null;

    final row = results.first;
    return {
      ...row,
      'is_online': row['is_online'] == 1,
      'is_available': row['is_available'] == 1,
      'verified': row['verified'] == 1,
      'profile_completed': row['profile_completed'] == 1,
    };
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
          'trip_id': trip['trip_id'] ?? '',
          'status': trip['status'] ?? '',
          'pickup_address': trip['pickup_address'] ?? '',
          'dropoff_address': trip['dropoff_address'] ?? '',
          'pickup_lat': trip['pickup_lat'],
          'pickup_lng': trip['pickup_lng'],
          'dropoff_lat': trip['dropoff_lat'],
          'dropoff_lng': trip['dropoff_lng'],
          'user_name': trip['user_name'] ?? '',
          'user_phone': trip['user_phone'] ?? '',
          'fare_amount': trip['fare_amount'],
          'distance_km': trip['distance_km'],
          'duration_minutes': trip['duration_minutes'],
          'driver_id': trip['driver_id'] ?? '',
          'created_at': trip['created_at'] ?? '',
          'accepted_at': trip['accepted_at'] ?? '',
          'completed_at': trip['completed_at'] ?? '',
          'cancelled_at': trip['cancelled_at'] ?? '',
          'cancel_reason': trip['cancel_reason'] ?? '',
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

  static Future<int> getCompletedTripsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cached_trips WHERE status = 'completed'",
    );
    return result.first['count'] as int? ?? 0;
  }

  // ============================================================
  // CACHED EARNINGS
  // ============================================================

  static Future<void> saveEarnings(List<Map<String, dynamic>> earnings) async {
    final db = await database;
    final batch = db.batch();

    for (var earning in earnings) {
      batch.insert(
        'cached_earnings',
        {
          'id': earning['id'] ?? '',
          'driver_id': earning['driver_id'] ?? '',
          'trip_id': earning['trip_id'] ?? '',
          'amount': earning['amount'],
          'created_at': earning['created_at'] ?? '',
          'last_synced': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ ${earnings.length} gains sauvegardés en local');
  }

  static Future<List<Map<String, dynamic>>> getCachedEarnings({int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    return await db.query(
      'cached_earnings',
      where: 'created_at >= ?',
      whereArgs: [startDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
  }

  static Future<Map<String, dynamic>> getCachedStatistics() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final monthStart = DateTime(now.year, now.month, 1);

    // Total earnings
    final totalResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM cached_earnings',
    );

    // Today
    final todayTrips = await db.rawQuery(
      "SELECT COUNT(*) as count, COALESCE(SUM(fare_amount), 0) as earnings "
      "FROM cached_trips WHERE status = 'completed' AND completed_at >= ?",
      [startOfDay.toIso8601String()],
    );

    // This week
    final weekTrips = await db.rawQuery(
      "SELECT COUNT(*) as count, COALESCE(SUM(fare_amount), 0) as earnings "
      "FROM cached_trips WHERE status = 'completed' AND completed_at >= ?",
      [weekStart.toIso8601String()],
    );

    // This month
    final monthTrips = await db.rawQuery(
      "SELECT COUNT(*) as count, COALESCE(SUM(fare_amount), 0) as earnings "
      "FROM cached_trips WHERE status = 'completed' AND completed_at >= ?",
      [monthStart.toIso8601String()],
    );

    // Total completed
    final completedResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cached_trips WHERE status = 'completed'",
    );

    return {
      'total_earnings': (totalResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'total_trips': completedResult.first['count'] as int? ?? 0,
      'completed_trips': completedResult.first['count'] as int? ?? 0,
      'today_trips': todayTrips.first['count'] as int? ?? 0,
      'today_earnings': (todayTrips.first['earnings'] as num?)?.toDouble() ?? 0.0,
      'week_trips': weekTrips.first['count'] as int? ?? 0,
      'week_earnings': (weekTrips.first['earnings'] as num?)?.toDouble() ?? 0.0,
      'month_trips': monthTrips.first['count'] as int? ?? 0,
      'month_earnings': (monthTrips.first['earnings'] as num?)?.toDouble() ?? 0.0,
      'rating': 0.0,
      'total_ratings': 0,
    };
  }

  // ============================================================
  // PENDING ACTIONS (File d'attente hors-ligne)
  // ============================================================

  static Future<void> addPendingAction({
    required String actionType,
    required String payload,
  }) async {
    final db = await database;
    await db.insert('pending_actions', {
      'action_type': actionType,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    print('📝 Action hors-ligne enregistrée: $actionType');
  }

  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query(
      'pending_actions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markActionCompleted(int actionId) async {
    final db = await database;
    await db.update(
      'pending_actions',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  static Future<void> clearCompletedActions() async {
    final db = await database;
    await db.delete(
      'pending_actions',
      where: 'status = ?',
      whereArgs: ['completed'],
    );
  }

  // ============================================================
  // APP SETTINGS
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

  // ============================================================
  // NETTOYAGE
  // ============================================================

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('driver_profile');
    await db.delete('cached_trips');
    await db.delete('cached_earnings');
    await db.delete('pending_actions');
    await db.delete('cached_app_settings');
    print('🗑️ Base de données locale vidée');
  }

  static Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
